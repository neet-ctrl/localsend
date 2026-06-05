import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
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

final hubCallProvider = NotifierProvider<HubCallNotifier, HubCallState>(
  (ref) => HubCallNotifier(),
);

class HubCallNotifier extends Notifier<HubCallState> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Timer? _pollTimer;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  @override
  HubCallState init() {
    _startPolling();
    return const HubCallState();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (state.status == HubCallStatus.idle) {
        final offer = HubIncomingBuffer.instance.drainCallOffer();
        if (offer != null) {
          final deviceIp = offer['callerIp'] as String? ?? '';
          final devicePort = offer['callerPort'] as int? ?? 53317;
          final deviceAlias = offer['callerAlias'] as String? ?? 'Unknown';
          final callType = offer['callType'] == 'video' ? HubCallType.video : HubCallType.voice;
          // Respect HTTPS flag sent by the caller; default false for LAN.
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

      if (state.status == HubCallStatus.outgoing) {
        final answer = HubIncomingBuffer.instance.drainCallAnswer();
        if (answer != null) {
          _log.info(HubLogCategory.calls, 'Received call answer from remote');
          await _handleRemoteAnswer(answer);
        }
      }

      if (state.status == HubCallStatus.active || state.status == HubCallStatus.outgoing) {
        final candidates = HubIncomingBuffer.instance.drainIceCandidates();
        for (final c in candidates) {
          try {
            _log.info(HubLogCategory.calls, 'Adding ICE candidate: ${c['candidate']}');
            await _peerConnection?.addCandidate(RTCIceCandidate(
              c['candidate'] as String?,
              c['sdpMid'] as String?,
              c['sdpMLineIndex'] as int?,
            ));
          } catch (e) {
            _log.warn(HubLogCategory.calls, 'Failed to add ICE candidate: $e');
          }
        }
        if (HubIncomingBuffer.instance.drainHangup()) {
          _log.info(HubLogCategory.calls, 'Remote hangup received');
          await endCall();
        }
      }
    });
  }

  Future<void> startCall(Device device, HubCallType type) async {
    _log.info(HubLogCategory.calls, 'Starting ${type.name} call to ${device.alias} (${device.ip}:${device.port})');
    try {
      await _initRenderers();
      _peerConnection = await _createPeerConnection(device);

      final constraints = <String, dynamic>{
        'audio': true,
        'video': type == HubCallType.video
            ? {'width': 1280, 'height': 720, 'facingMode': 'user'}
            : false,
      };
      _log.info(HubLogCategory.calls, 'Requesting getUserMedia: $constraints');
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      if (type == HubCallType.video) {
        localRenderer.srcObject = _localStream;
      }

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _log.info(HubLogCategory.calls, 'Created offer SDP (${offer.sdp?.length ?? 0} chars), sending to remote');

      final myAlias = ref.read(settingsProvider).alias;
      final myPort = ref.read(serverProvider)?.port ?? 53317;
      final myFingerprint = ref.read(securityProvider).certificateHash;
      final ip = device.ip;
      if (ip != null) {
        await _httpPost(
          ip,
          device.port,
          device.https,
          '/hub/call/offer',
          {
            'sdp': offer.sdp,
            'type': offer.type,
            'callType': type.name,
            'callerAlias': myAlias,
            'callerPort': myPort,
            'callerFingerprint': myFingerprint,
            'callerHttps': device.https,
          },
        );
      }

      state = state.copyWith(
        status: HubCallStatus.outgoing,
        type: type,
        remoteDevice: device,
      );
      // Play ringback tone on the caller's side (like carrier "ring ring")
      HubRingbackService.instance.startRingback();
    } catch (e, st) {
      _log.error(HubLogCategory.calls, 'startCall failed: $e\n$st');
      HubRingbackService.instance.stopRingback();
      state = state.copyWith(status: HubCallStatus.idle, errorMessage: e.toString());
    }
  }

  Future<void> acceptCall() async {
    HubRingtoneService.instance.stop();
    final sdp = state.incomingSdp;
    final sdpType = state.incomingSdpType;
    final device = state.remoteDevice;
    if (sdp == null || device == null) return;
    _log.info(HubLogCategory.calls, 'Accepting call from ${device.alias}');

    try {
      await _initRenderers();
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
      if (type == HubCallType.video) {
        localRenderer.srcObject = _localStream;
      }

      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, sdpType ?? 'offer'));
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _log.info(HubLogCategory.calls, 'Created answer SDP, sending to ${device.ip}:${device.port}');

      final ip = device.ip;
      if (ip != null) {
        await _httpPost(ip, device.port, device.https, '/hub/call/answer', {
          'sdp': answer.sdp,
          'type': answer.type,
        });
      }

      state = state.copyWith(
        status: HubCallStatus.active,
        startTime: DateTime.now(),
        clearIncoming: true,
      );
      _log.info(HubLogCategory.calls, 'Call accepted — now active');
    } catch (e, st) {
      _log.error(HubLogCategory.calls, 'acceptCall failed: $e\n$st');
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
    HubRingbackService.instance.stopRingback(); // stop if caller cancelled while outgoing
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
    state = state.copyWith(isSpeakerOn: !state.isSpeakerOn);
    _log.info(HubLogCategory.calls, 'Speaker: ${state.isSpeakerOn}');
  }

  Future<void> _handleRemoteAnswer(Map<String, dynamic> answer) async {
    try {
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'] as String?, answer['type'] as String?),
      );
      HubRingbackService.instance.stopRingback(); // call connected — stop ringback
      state = state.copyWith(status: HubCallStatus.active, startTime: DateTime.now());
      _log.info(HubLogCategory.calls, 'Remote answer applied — call active');
    } catch (e) {
      _log.error(HubLogCategory.calls, 'setRemoteDescription (answer) failed: $e');
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(Device device) async {
    _log.info(HubLogCategory.calls, 'Creating RTCPeerConnection (LAN-only, no STUN)');
    final config = <String, dynamic>{
      'iceServers': [],
      'sdpSemantics': 'unified-plan',
    };
    final pc = await createPeerConnection(config);

    pc.onIceCandidate = (candidate) async {
      _log.info(HubLogCategory.calls, 'ICE candidate → ${device.ip}: ${candidate.candidate}');
      final ip = device.ip;
      if (ip != null) {
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
        state = state.copyWith(status: HubCallStatus.active, startTime: state.startTime ?? DateTime.now());
      }
    };

    pc.onConnectionState = (connectionState) {
      _log.info(HubLogCategory.calls, 'PeerConnection state: $connectionState');
      if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        endCall();
      }
    };

    pc.onIceConnectionState = (state) {
      _log.info(HubLogCategory.calls, 'ICE connection state: $state');
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
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
    try {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    } catch (_) {}
    _log.info(HubLogCategory.calls, 'Call resources cleaned up');
  }

  /// POST to a remote Hub endpoint. Uses [lanHttpClient] so self-signed TLS
  /// certificates are accepted — LocalSend LAN devices always use self-signed certs.
  Future<void> _httpPost(String ip, int port, bool https, String path, Map<String, dynamic> body) async {
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
