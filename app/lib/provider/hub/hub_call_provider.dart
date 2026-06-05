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
  Timer? _pollTimer;

  // ICE candidates that arrived before setRemoteDescription — buffered, then flushed
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescSet = false;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  @override
  HubCallState init() {
    _startPolling();
    return const HubCallState();
  }

  // ─── Platform audio mode ──────────────────────────────────────────────────
  // Sets Android AudioManager.MODE_IN_COMMUNICATION so the OS routes audio
  // through the earpiece/speaker path used by WebRTC and engages hardware
  // echo-cancellation and noise-suppression. On iOS this is a no-op (AVAudioSession
  // is handled internally by WebRTC).
  Future<void> _setCallAudioMode(bool active) async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod('setCallAudioMode', {'active': active});
      _log.info(HubLogCategory.calls, 'setCallAudioMode($active) OK');
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'setCallAudioMode($active) error: $e');
    }
  }

  // ─── ICE gathering — Jami approach ───────────────────────────────────────
  // Jami gathers ALL ICE candidates first, embeds them in the SDP, then
  // sends ONE complete SDP with no trickle-ICE signalling needed.
  // We do the same: after setLocalDescription we wait for
  // RTCIceGatheringStateComplete (up to 10 s) then read back the final
  // localDescription — which now contains all `a=candidate:` lines.
  // The remote side calls setRemoteDescription(completeSdp) and ICE
  // negotiation starts immediately with every candidate already available,
  // eliminating all timing races.
  Future<RTCSessionDescription> _waitForGatheringComplete(
    RTCSessionDescription fallback,
  ) async {
    final completer = Completer<void>();

    _peerConnection!.onIceGatheringState = (RTCIceGatheringState s) {
      _log.info(HubLogCategory.calls, 'ICE gathering state: $s');
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };

    try {
      await completer.future.timeout(const Duration(seconds: 10));
      _log.info(HubLogCategory.calls, 'ICE gathering complete — all candidates embedded');
    } catch (_) {
      _log.warn(HubLogCategory.calls, 'ICE gathering timeout (10 s) — using partial candidates');
    }

    return (await _peerConnection!.getLocalDescription()) ?? fallback;
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
      // If both sides use the complete-gathering approach the remote SDP already
      // contains all candidates and addCandidate is rarely needed. We keep it
      // as a fallback for cross-client compatibility.
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
              _log.info(HubLogCategory.calls, 'Adding trickle ICE candidate: ${c['candidate']}');
              await _peerConnection!.addCandidate(candidate);
            } catch (e) {
              _log.warn(HubLogCategory.calls, 'Failed to add trickle candidate: $e');
            }
          } else {
            _pendingCandidates.add(candidate);
            _log.info(HubLogCategory.calls, 'Buffered trickle ICE candidate (remote desc pending)');
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
      await _initRenderers();
      _remoteDescSet = false;
      _pendingCandidates.clear();
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

      // ── Jami ICE approach: gather ALL candidates before sending SDP ──────
      final initialOffer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(initialOffer);
      _log.info(HubLogCategory.calls, 'Waiting for ICE gathering to complete...');
      final completeOffer = await _waitForGatheringComplete(initialOffer);
      _log.info(HubLogCategory.calls,
          'Sending complete offer SDP (${completeOffer.sdp?.length ?? 0} chars) to remote');

      final myAlias = ref.read(settingsProvider).alias;
      final myPort = ref.read(serverProvider)?.port ?? 53317;
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
          'callerHttps': device.https,
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
    final sdp = state.incomingSdp;
    final sdpType = state.incomingSdpType;
    final device = state.remoteDevice;
    if (sdp == null || device == null) return;
    _log.info(HubLogCategory.calls, 'Accepting call from ${device.alias}');

    try {
      await _initRenderers();
      _remoteDescSet = false;
      _pendingCandidates.clear();
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

      // Remote offer already contains all candidates (complete-gathering approach)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, sdpType ?? 'offer'),
      );
      _remoteDescSet = true;
      await _flushPendingCandidates();

      // ── Jami ICE approach: gather ALL candidates before sending answer ────
      final initialAnswer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(initialAnswer);
      _log.info(HubLogCategory.calls, 'Waiting for ICE gathering to complete (callee)...');
      final completeAnswer = await _waitForGatheringComplete(initialAnswer);
      _log.info(HubLogCategory.calls,
          'Sending complete answer SDP (${completeAnswer.sdp?.length ?? 0} chars)');

      final ip = device.ip;
      if (ip != null) {
        await _httpPost(ip, device.port, device.https, '/hub/call/answer', {
          'sdp': completeAnswer.sdp,
          'type': completeAnswer.type,
        });
      }

      // Enable Android call audio mode + speakerphone
      await _setCallAudioMode(true);
      _setSpeakerphone(true);

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
    final device = state.remoteDevice;
    final ip = device?.ip;
    _log.info(HubLogCategory.calls, 'Rejecting call from ${device?.alias}');
    if (ip != null) {
      await _httpPost(ip, device!.port, device.https, '/hub/call/hangup', {});
    }
    state = const HubCallState();
  }

  Future<void> endCall() async {
    HubRingtoneService.instance.stop();
    HubRingbackService.instance.stopRingback();
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
  }

  void toggleMute() {
    final muted = !state.isMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
    state = state.copyWith(isMuted: muted);
    _log.info(HubLogCategory.calls, 'Mute: $muted');
  }

  void toggleVideo() {
    final disabled = !state.isVideoEnabled;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !disabled);
    state = state.copyWith(isVideoEnabled: !disabled);
    _log.info(HubLogCategory.calls, 'Video enabled: ${!disabled}');
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
      // Remote answer SDP already contains all candidates (complete-gathering approach)
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'] as String?, answer['type'] as String?),
      );
      _remoteDescSet = true;
      await _flushPendingCandidates();

      await _setCallAudioMode(true);
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
      // Restrict to local network candidates only (no server-reflexive, no relay)
      'iceTransportPolicy': 'all',
    };
    final pc = await createPeerConnection(config);

    // Still forward trickle ICE candidates to remote as a best-effort fallback.
    // If the remote side supports the complete-gathering approach, these will
    // simply be ignored (the SDP already had all the candidates).
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
      if (event.streams.isNotEmpty) {
        _log.info(HubLogCategory.calls, 'Remote track received (${event.track.kind})');
        remoteRenderer.srcObject = event.streams.first;
        state = state.copyWith(
          status: HubCallStatus.active,
          startTime: state.startTime ?? DateTime.now(),
          hasRemoteTrack: true,
        );
      }
    };

    pc.onConnectionState = (connectionState) {
      _log.info(HubLogCategory.calls, 'PeerConnection state: $connectionState');
      if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        endCall();
      }
    };

    pc.onIceConnectionState = (s) {
      _log.info(HubLogCategory.calls, 'ICE connection state: $s');
    };

    return pc;
  }

  Future<void> _initRenderers() async {
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
    } catch (e) {
      _log.warn(HubLogCategory.calls, 'Renderer init error (non-fatal): $e');
    }
  }

  Future<void> _cleanup() async {
    _remoteDescSet = false;
    _pendingCandidates.clear();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
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
