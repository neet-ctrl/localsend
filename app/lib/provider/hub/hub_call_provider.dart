import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:localsend_app/model/hub/hub_call_state.dart';
import 'package:localsend_app/provider/hub/hub_ringback_service.dart';
import 'package:localsend_app/provider/hub/hub_ringtone_service.dart';
import 'package:localsend_app/provider/network/server/controller/hub_controller.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/hub_http.dart';
import 'package:localsend_app/util/hub_logger.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _log = HubLogger.instance;

// MethodChannel shared with MainActivity / HubForegroundService
const _platform = MethodChannel('org.localsend.localsend_app/localsend');

final hubCallProvider = NotifierProvider<HubCallNotifier, HubCallState>(
  (ref) => HubCallNotifier(),
);

class HubCallNotifier extends Notifier<HubCallState> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  // Pre-created empty stream used as a container for remote tracks that
  // arrive via onTrack with no stream attached (common in flutter_webrtc).
  MediaStream? _remoteStream;
  Timer? _pollTimer;

  // Guard against reentrant endCall() calls (e.g. triggered by onConnectionState
  // firing during peerConnection.close()).
  bool _isEnding = false;

  // ICE candidates that arrived before setRemoteDescription — buffered, then flushed
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescSet = false;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;

  @override
  HubCallState init() {
    // Listen for incoming accept/decline actions triggered by notification
    // buttons or overlay window buttons.
    _platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'notificationCallAction':
          final action = call.arguments as String?;
          _log.info(HubLogCategory.calls, 'Notification action received: $action');
          if (action == 'accept' && state.status == HubCallStatus.incoming) {
            await acceptCall();
          } else if (action == 'decline' && state.status == HubCallStatus.incoming) {
            await rejectCall();
          }
          break;
      }
    });
    _startPolling();
    // Proactively check for the overlay permission and request it if absent.
    // This opens the system settings page once so the user can grant it,
    // ensuring future incoming calls show the full-screen overlay.
    _checkAndRequestOverlayPermission();
    return const HubCallState();
  }

  // ─── Overlay permission ───────────────────────────────────────────────────
  Future<void> _checkAndRequestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final granted =
          await _platform.invokeMethod<bool>('checkOverlayPermission') ?? false;
      if (!granted) {
        _log.info(HubLogCategory.calls,
            'Overlay permission not granted — opening system settings');
        await _platform.invokeMethod('requestOverlayPermission');
      } else {
        _log.info(HubLogCategory.calls, 'Overlay permission already granted');
      }
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'checkOverlayPermission error: $e');
    }
  }

  // ─── Call overlay ─────────────────────────────────────────────────────────
  Future<void> _showCallOverlay(String callerName, HubCallType type) async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod('showCallOverlay', {
        'callerName': callerName,
        'callType': type.name,
      });
      _log.info(HubLogCategory.calls, 'showCallOverlay($callerName) OK');
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'showCallOverlay error: $e');
    }
  }

  Future<void> _dismissCallOverlay() async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod('dismissCallOverlay');
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'dismissCallOverlay error: $e');
    }
  }

  // ─── Platform audio mode ──────────────────────────────────────────────────
  Future<void> _setCallAudioMode(bool active) async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod('setCallAudioMode', {'active': active});
      _log.info(HubLogCategory.calls, 'setCallAudioMode($active) OK');
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'setCallAudioMode($active) error: $e');
    }
  }

  // ─── Incoming call notification ───────────────────────────────────────────
  Future<void> _showIncomingCallNotification(String callerName, HubCallType type) async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod('showIncomingCallNotification', {
        'callerName': callerName,
        'callType': type.name,
      });
      _log.info(HubLogCategory.calls, 'showIncomingCallNotification($callerName) OK');
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'showIncomingCallNotification error: $e');
    }
  }

  Future<void> _dismissCallNotification() async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod('dismissCallNotification');
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'dismissCallNotification error: $e');
    }
  }

  // ─── ICE gathering ───────────────────────────────────────────────────────
  // IMPORTANT: the gathering-state handler MUST be attached BEFORE calling
  // setLocalDescription — otherwise on fast LAN networks the "complete" event
  // fires before the listener is registered and we miss it, causing a full
  // timeout delay on every call (which looks like silence / no video).
  Future<RTCSessionDescription> _setLocalDescriptionAndGather(
    RTCSessionDescription desc,
  ) async {
    final completer = Completer<void>();

    // Attach handler FIRST, then set local description.
    _peerConnection!.onIceGatheringState = (RTCIceGatheringState s) {
      _log.info(HubLogCategory.calls, 'ICE gathering state: $s');
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };

    await _peerConnection!.setLocalDescription(desc);

    try {
      await completer.future.timeout(const Duration(seconds: 6));
      _log.info(HubLogCategory.calls, 'ICE gathering complete — all candidates embedded');
    } catch (_) {
      _log.warn(HubLogCategory.calls, 'ICE gathering timeout (6 s) — using partial SDP');
    }

    return (await _peerConnection!.getLocalDescription()) ?? desc;
  }

  // ─── Poll loop ────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      // Incoming call offer
      if (state.status == HubCallStatus.idle) {
        final offer = HubIncomingBuffer.instance.drainCallOffer();
        if (offer != null) {
          final deviceIp = offer['callerIp'] as String? ?? '';
          final devicePort = offer['callerPort'] as int? ?? 53317;
          final deviceAlias = offer['callerAlias'] as String? ?? 'Unknown';
          final callType = offer['callType'] == 'video' ? HubCallType.video : HubCallType.voice;
          final deviceHttps = offer['callerHttps'] as bool? ?? false;
          _log.info(HubLogCategory.calls,
              'Incoming ${callType.name} call from $deviceAlias ($deviceIp:$devicePort https=$deviceHttps)');
          final fakeDevice = Device(
            signalingId: null,
            ip: deviceIp,
            version: '1.0',
            port: devicePort,
            https: deviceHttps,
            fingerprint: offer['callerFingerprint'] as String? ?? '',
            alias: deviceAlias,
            deviceModel: null,
            deviceType: DeviceType.desktop,
            download: false,
            discoveryMethods: const {},
          );
          state = state.copyWith(
            status: HubCallStatus.incoming,
            type: callType,
            remoteDevice: fakeDevice,
            incomingSdp: offer['sdp'] as String?,
            incomingSdpType: offer['type'] as String?,
          );
          HubRingtoneService.instance.start();
          // Show the full-screen TYPE_APPLICATION_OVERLAY window (appears on
          // top of every app including lock screen when SYSTEM_ALERT_WINDOW is
          // granted) AND a heads-up notification as fallback.
          await _showCallOverlay(deviceAlias, callType);
          await _showIncomingCallNotification(deviceAlias, callType);
        }
      }

      // Outgoing: wait for answer
      if (state.status == HubCallStatus.outgoing) {
        final answer = HubIncomingBuffer.instance.drainCallAnswer();
        if (answer != null) {
          _log.info(HubLogCategory.calls, 'Received call answer from remote');
          await _handleRemoteAnswer(answer);
        }
      }

      // Active / outgoing / incoming: process trickle-ICE candidates (fallback)
      if (state.status == HubCallStatus.active ||
          state.status == HubCallStatus.outgoing ||
          state.status == HubCallStatus.incoming) {
        final candidates = HubIncomingBuffer.instance.drainIceCandidates();
        for (final c in candidates) {
          final candidate = RTCIceCandidate(
            c['candidate'] as String?,
            c['sdpMid'] as String?,
            c['sdpMLineIndex'] as int?,
          );
          if (_remoteDescSet && _peerConnection != null) {
            try {
              await _peerConnection!.addCandidate(candidate);
            } catch (e) {
              _log.warn(HubLogCategory.calls, 'Failed to add trickle candidate: $e');
            }
          } else {
            _pendingCandidates.add(candidate);
          }
        }

        if (HubIncomingBuffer.instance.drainHangup()) {
          _log.info(HubLogCategory.calls, 'Remote hangup received');
          await endCall();
        }
      }
    });
  }

  Future<void> _flushPendingCandidates() async {
    if (_pendingCandidates.isEmpty) return;
    _log.info(HubLogCategory.calls, 'Flushing ${_pendingCandidates.length} buffered ICE candidates');
    for (final c in List<RTCIceCandidate>.from(_pendingCandidates)) {
      try {
        await _peerConnection?.addCandidate(c);
      } catch (e) {
        _log.warn(HubLogCategory.calls, 'Buffered candidate failed: $e');
      }
    }
    _pendingCandidates.clear();
  }

  // ─── Outgoing call ────────────────────────────────────────────────────────
  Future<void> startCall(Device device, HubCallType type) async {
    _log.info(HubLogCategory.calls,
        'Starting ${type.name} call to ${device.alias} (${device.ip}:${device.port})');
    try {
      // Set audio mode FIRST so WebRTC routes audio through the right path
      // from the very beginning (earpiece/speaker, hardware AEC/NS).
      await _setCallAudioMode(true);

      await _initRenderers();
      _remoteDescSet = false;
      _pendingCandidates.clear();
      // Pre-create the remote stream container BEFORE creating the peer
      // connection so the onTrack handler can add tracks to it immediately,
      // even when flutter_webrtc fires onTrack with no stream attached.
      _remoteStream = await createLocalMediaStream(
          'remote_${DateTime.now().millisecondsSinceEpoch}');
      _peerConnection = await _createPeerConnection(device);

      final constraints = <String, dynamic>{
        'audio': true,
        'video': type == HubCallType.video
            ? {'width': 1280, 'height': 720, 'facingMode': 'user'}
            : false,
      };
      _log.info(HubLogCategory.calls, 'getUserMedia: $constraints');
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      if (type == HubCallType.video) localRenderer.srcObject = _localStream;

      final initialOffer = await _peerConnection!.createOffer();
      _log.info(HubLogCategory.calls, 'Waiting for ICE gathering (caller)...');
      final completeOffer = await _setLocalDescriptionAndGather(initialOffer);
      _log.info(HubLogCategory.calls,
          'Sending complete offer SDP (${completeOffer.sdp?.length ?? 0} chars) to remote');

      final myAlias = ref.read(settingsProvider).alias;
      final myPort = ref.read(serverProvider)?.port ?? 53317;
      // Use OUR OWN https setting, not the remote device's.
      final myHttps = ref.read(serverProvider)?.https ?? false;
      final myFingerprint = ref.read(securityProvider).certificateHash;
      final ip = device.ip;
      if (ip != null) {
        await _httpPost(ip, device.port, device.https, '/hub/call/offer', {
          'sdp': completeOffer.sdp,
          'type': completeOffer.type,
          'callType': type.name,
          'callerAlias': myAlias,
          'callerPort': myPort,
          'callerFingerprint': myFingerprint,
          'callerHttps': myHttps,
        });
      }

      state = state.copyWith(
        status: HubCallStatus.outgoing,
        type: type,
        remoteDevice: device,
      );
      HubRingbackService.instance.startRingback();
    } catch (e, st) {
      _log.error(HubLogCategory.calls, 'startCall failed: $e\n$st');
      HubRingbackService.instance.stopRingback();
      await _setCallAudioMode(false);
      state = state.copyWith(status: HubCallStatus.idle, errorMessage: e.toString());
    }
  }

  // ─── Accept incoming call ─────────────────────────────────────────────────
  Future<void> acceptCall() async {
    HubRingtoneService.instance.stop();
    await _dismissCallOverlay();
    await _dismissCallNotification();
    final sdp = state.incomingSdp;
    final sdpType = state.incomingSdpType;
    final device = state.remoteDevice;
    if (sdp == null || device == null) return;
    _log.info(HubLogCategory.calls, 'Accepting call from ${device.alias}');

    try {
      // Set audio mode FIRST — must be done before getUserMedia so Android
      // routes audio through MODE_IN_COMMUNICATION from the start.
      await _setCallAudioMode(true);
      _setSpeakerphone(true);

      await _initRenderers();
      _remoteDescSet = false;
      _pendingCandidates.clear();
      // Pre-create the remote stream container BEFORE creating the peer
      // connection so the onTrack handler can add tracks to it immediately.
      _remoteStream = await createLocalMediaStream(
          'remote_${DateTime.now().millisecondsSinceEpoch}');
      _peerConnection = await _createPeerConnection(device);

      final type = state.type ?? HubCallType.voice;
      final constraints = <String, dynamic>{
        'audio': true,
        'video': type == HubCallType.video
            ? {'width': 1280, 'height': 720, 'facingMode': 'user'}
            : false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      if (type == HubCallType.video) localRenderer.srcObject = _localStream;

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, sdpType ?? 'offer'),
      );
      _remoteDescSet = true;
      await _flushPendingCandidates();

      final initialAnswer = await _peerConnection!.createAnswer();
      _log.info(HubLogCategory.calls, 'Waiting for ICE gathering (callee)...');
      final completeAnswer = await _setLocalDescriptionAndGather(initialAnswer);
      _log.info(HubLogCategory.calls,
          'Sending complete answer SDP (${completeAnswer.sdp?.length ?? 0} chars)');

      final ip = device.ip;
      if (ip != null) {
        await _httpPost(ip, device.port, device.https, '/hub/call/answer', {
          'sdp': completeAnswer.sdp,
          'type': completeAnswer.type,
        });
      }

      state = state.copyWith(
        status: HubCallStatus.active,
        startTime: DateTime.now(),
        isSpeakerOn: true,
        clearIncoming: true,
      );
      _log.info(HubLogCategory.calls, 'Call accepted — now active');
    } catch (e, st) {
      _log.error(HubLogCategory.calls, 'acceptCall failed: $e\n$st');
      await _setCallAudioMode(false);
      state = state.copyWith(status: HubCallStatus.idle, errorMessage: e.toString());
    }
  }

  Future<void> rejectCall() async {
    HubRingtoneService.instance.stop();
    await _dismissCallOverlay();
    await _dismissCallNotification();
    final device = state.remoteDevice;
    final ip = device?.ip;
    _log.info(HubLogCategory.calls, 'Rejecting call from ${device?.alias}');
    if (ip != null) {
      await _httpPost(ip, device!.port, device.https, '/hub/call/hangup', {});
    }
    state = const HubCallState();
  }

  Future<void> endCall() async {
    // Guard against reentrant calls (e.g. onConnectionState firing during
    // peerConnection.close() → would call endCall() again → crash).
    if (_isEnding) {
      _log.warn(HubLogCategory.calls, 'endCall() already in progress — ignoring reentrant call');
      return;
    }
    _isEnding = true;

    try {
      HubRingtoneService.instance.stop();
      HubRingbackService.instance.stopRingback();
      await _dismissCallOverlay();
      await _dismissCallNotification();
      final device = state.remoteDevice;
      final ip = device?.ip;
      _log.info(HubLogCategory.calls, 'Ending call with ${device?.alias}');
      if (ip != null) {
        try {
          await _httpPost(ip, device!.port, device.https, '/hub/call/hangup', {});
        } catch (e) {
          _log.warn(HubLogCategory.calls, 'Hangup POST failed (ignored): $e');
        }
      }
      await _cleanup();
      state = const HubCallState(status: HubCallStatus.ended);
      await Future.delayed(const Duration(seconds: 2));
      state = const HubCallState();
    } finally {
      _isEnding = false;
    }
  }

  void toggleMute() {
    final muted = !state.isMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
    state = state.copyWith(isMuted: muted);
    _log.info(HubLogCategory.calls, 'Mute: $muted');
  }

  void toggleVideo() {
    final nowEnabled = !state.isVideoEnabled;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = nowEnabled);
    state = state.copyWith(isVideoEnabled: nowEnabled);
    _log.info(HubLogCategory.calls, 'Video enabled: $nowEnabled');
  }

  void toggleHold() {
    state = state.copyWith(isOnHold: !state.isOnHold);
    _log.info(HubLogCategory.calls, 'Hold: ${state.isOnHold}');
  }

  void toggleSpeaker() {
    final isSpeaker = !state.isSpeakerOn;
    _setSpeakerphone(isSpeaker);
    state = state.copyWith(isSpeakerOn: isSpeaker);
    _log.info(HubLogCategory.calls, 'Speaker: $isSpeaker');
  }

  void _setSpeakerphone(bool on) {
    try {
      Helper.setSpeakerphoneOn(on);
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'setSpeakerphoneOn($on) failed: $e');
    }
  }

  // ─── Handle remote answer (caller side) ──────────────────────────────────
  Future<void> _handleRemoteAnswer(Map<String, dynamic> answer) async {
    try {
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'] as String?, answer['type'] as String?),
      );
      _remoteDescSet = true;
      await _flushPendingCandidates();

      // Audio mode was already set in startCall(); enable speakerphone now.
      _setSpeakerphone(true);

      HubRingbackService.instance.stopRingback();
      state = state.copyWith(
        status: HubCallStatus.active,
        startTime: DateTime.now(),
        isSpeakerOn: true,
      );
      _log.info(HubLogCategory.calls, 'Remote answer applied — call active');
    } catch (e) {
      _log.error(HubLogCategory.calls, 'setRemoteDescription (answer) failed: $e');
    }
  }

  // ─── Peer connection factory ──────────────────────────────────────────────
  Future<RTCPeerConnection> _createPeerConnection(Device device) async {
    _log.info(HubLogCategory.calls, 'Creating RTCPeerConnection (LAN-only, no STUN/TURN)');
    final config = <String, dynamic>{
      'iceServers': [],
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all',
    };
    final pc = await createPeerConnection(config);

    pc.onIceCandidate = (candidate) async {
      final ip = device.ip;
      if (ip != null && candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _log.info(HubLogCategory.calls, 'Trickle ICE → ${device.ip}: ${candidate.candidate}');
        await _httpPost(ip, device.port, device.https, '/hub/call/ice', {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    pc.onTrack = (event) {
      // flutter_webrtc frequently fires onTrack with event.streams EMPTY —
      // the track is in event.track but no stream wraps it.  We pre-create
      // _remoteStream in startCall/acceptCall and add every arriving track
      // into it unconditionally so the renderer always gets a source.
      _log.info(HubLogCategory.calls,
          'onTrack: kind=${event.track.kind} streams=${event.streams.length}');

      if (event.streams.isNotEmpty) {
        // Happy path: stream already attached — use it directly.
        _remoteStream = event.streams.first;
        remoteRenderer.srcObject = _remoteStream;
      } else if (_remoteStream != null) {
        // Common path: no stream — add track to our pre-created container.
        _remoteStream!.addTrack(event.track);
        remoteRenderer.srcObject = _remoteStream;
      } else {
        // Defensive: _remoteStream not yet ready — nothing to do; it will be
        // assigned by the next track event or set externally.
        _log.warn(HubLogCategory.calls, 'onTrack: _remoteStream is null — track dropped!');
      }

      state = state.copyWith(
        status: HubCallStatus.active,
        startTime: state.startTime ?? DateTime.now(),
        hasRemoteTrack: true,
      );
    };

    pc.onConnectionState = (connectionState) {
      _log.info(HubLogCategory.calls, 'PeerConnection state: $connectionState');
      // Do NOT call endCall() directly from here — doing so while peerConnection.close()
      // is running creates a reentrant endCall() that crashes the app (black screen).
      // The poll loop handles remote hangup via drainHangup(). For unexpected
      // disconnects, trigger endCall only when _isEnding is false.
      if (!_isEnding &&
          (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
           connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected)) {
        _log.info(HubLogCategory.calls, 'Connection dropped unexpectedly — ending call');
        endCall();
      }
    };

    pc.onIceConnectionState = (s) {
      _log.info(HubLogCategory.calls, 'ICE connection state: $s');
    };

    return pc;
  }

  Future<void> _initRenderers() async {
    if (_renderersInitialized) return;
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersInitialized = true;
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'Renderer init error (non-fatal): $e');
    }
  }

  Future<void> _cleanup() async {
    _remoteDescSet = false;
    _pendingCandidates.clear();

    // Stop and dispose local media tracks
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;

    // Dispose the remote stream container
    try {
      _remoteStream?.getTracks().forEach((t) => t.stop());
      _remoteStream?.dispose();
    } catch (_) {}
    _remoteStream = null;

    // Null out the peer connection BEFORE closing it.
    // This prevents the onConnectionState callback from firing and
    // triggering a reentrant endCall() while close() is running.
    final pc = _peerConnection;
    _peerConnection = null;
    try {
      await pc?.close();
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'peerConnection.close() error (ignored): $e');
    }

    // Clear renderer sources — do NOT dispose them here. The renderers are
    // notifier-lifetime objects reused across calls. Disposing them between
    // calls causes "initialized on a disposed renderer" crashes on the next call.
    try {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    } catch (_) {}

    await _setCallAudioMode(false);
    _log.info(HubLogCategory.calls, 'Call resources cleaned up');
  }

  Future<void> _httpPost(
    String ip,
    int port,
    bool https,
    String path,
    Map<String, dynamic> body,
  ) async {
    final scheme = https ? 'https' : 'http';
    final url = '$scheme://$ip:$port$path';
    _log.info(HubLogCategory.calls, 'POST $url');
    try {
      final client = lanHttpClient();
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final resp = await request.close();
      await resp.drain<void>();
      client.close();
      _log.info(HubLogCategory.calls, 'POST $path → ${resp.statusCode}');
    } catch (e) {
      _log.error(HubLogCategory.calls, 'POST $path failed: $e');
    }
  }
}
