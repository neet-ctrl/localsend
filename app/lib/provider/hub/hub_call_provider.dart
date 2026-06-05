import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:localsend_app/model/hub/hub_call_state.dart';
import 'package:localsend_app/provider/network/server/controller/hub_controller.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

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
          final fakeDevice = Device(
            signalingId: null,
            ip: deviceIp,
            version: '1.0',
            port: devicePort,
            https: false,
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
        }
      }

      if (state.status == HubCallStatus.outgoing) {
        final answer = HubIncomingBuffer.instance.drainCallAnswer();
        if (answer != null) {
          await _handleRemoteAnswer(answer);
        }
      }

      if (state.status == HubCallStatus.active || state.status == HubCallStatus.outgoing) {
        final candidates = HubIncomingBuffer.instance.drainIceCandidates();
        for (final c in candidates) {
          try {
            await _peerConnection?.addCandidate(RTCIceCandidate(
              c['candidate'] as String?,
              c['sdpMid'] as String?,
              c['sdpMLineIndex'] as int?,
            ));
          } catch (_) {}
        }
        if (HubIncomingBuffer.instance.drainHangup()) {
          await endCall();
        }
      }
    });
  }

  Future<void> startCall(Device device, HubCallType type) async {
    try {
      await _initRenderers();
      _peerConnection = await _createPeerConnection(device);

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

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final myAlias = ref.read(settingsProvider).alias;
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
          },
        );
      }

      state = state.copyWith(
        status: HubCallStatus.outgoing,
        type: type,
        remoteDevice: device,
      );
    } catch (e) {
      state = state.copyWith(status: HubCallStatus.idle, errorMessage: e.toString());
    }
  }

  Future<void> acceptCall() async {
    final sdp = state.incomingSdp;
    final sdpType = state.incomingSdpType;
    final device = state.remoteDevice;
    if (sdp == null || device == null) return;

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
    } catch (e) {
      state = state.copyWith(status: HubCallStatus.idle, errorMessage: e.toString());
    }
  }

  Future<void> rejectCall() async {
    final device = state.remoteDevice;
    final ip = device?.ip;
    if (ip != null) {
      await _httpPost(ip, device!.port, device.https, '/hub/call/hangup', {});
    }
    state = const HubCallState();
  }

  Future<void> endCall() async {
    final device = state.remoteDevice;
    final ip = device?.ip;
    if (ip != null) {
      try {
        await _httpPost(ip, device!.port, device.https, '/hub/call/hangup', {});
      } catch (_) {}
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
  }

  void toggleVideo() {
    final disabled = !state.isVideoEnabled;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !disabled);
    state = state.copyWith(isVideoEnabled: !disabled);
  }

  void toggleHold() {
    state = state.copyWith(isOnHold: !state.isOnHold);
  }

  void toggleSpeaker() {
    state = state.copyWith(isSpeakerOn: !state.isSpeakerOn);
  }

  Future<void> _handleRemoteAnswer(Map<String, dynamic> answer) async {
    try {
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'] as String?, answer['type'] as String?),
      );
      state = state.copyWith(status: HubCallStatus.active, startTime: DateTime.now());
    } catch (_) {}
  }

  Future<RTCPeerConnection> _createPeerConnection(Device device) async {
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };
    final pc = await createPeerConnection(config);

    pc.onIceCandidate = (candidate) async {
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
        remoteRenderer.srcObject = event.streams.first;
        state = state.copyWith(status: HubCallStatus.active, startTime: state.startTime ?? DateTime.now());
      }
    };

    pc.onConnectionState = (connectionState) {
      if (connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        endCall();
      }
    };

    return pc;
  }

  Future<void> _initRenderers() async {
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
    } catch (_) {}
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
  }

  Future<void> _httpPost(String ip, int port, bool https, String path, Map<String, dynamic> body) async {
    try {
      final scheme = https ? 'https' : 'http';
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$scheme://$ip:$port$path'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      await (await request.close()).drain<void>();
      client.close();
    } catch (_) {}
  }

}
