import 'package:common/model/device.dart';

enum HubCallType { voice, video }

enum HubCallStatus { idle, incoming, outgoing, active, ended }

class HubCallState {
  final HubCallStatus status;
  final HubCallType? type;
  final Device? remoteDevice;
  final DateTime? startTime;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isVideoEnabled;
  final bool isOnHold;
  final String? incomingSdp;
  final String? incomingSdpType;
  final String? errorMessage;

  const HubCallState({
    this.status = HubCallStatus.idle,
    this.type,
    this.remoteDevice,
    this.startTime,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isVideoEnabled = true,
    this.isOnHold = false,
    this.incomingSdp,
    this.incomingSdpType,
    this.errorMessage,
  });

  HubCallState copyWith({
    HubCallStatus? status,
    HubCallType? type,
    Device? remoteDevice,
    DateTime? startTime,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isVideoEnabled,
    bool? isOnHold,
    String? incomingSdp,
    String? incomingSdpType,
    String? errorMessage,
    bool clearError = false,
    bool clearIncoming = false,
  }) =>
      HubCallState(
        status: status ?? this.status,
        type: type ?? this.type,
        remoteDevice: remoteDevice ?? this.remoteDevice,
        startTime: startTime ?? this.startTime,
        isMuted: isMuted ?? this.isMuted,
        isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
        isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
        isOnHold: isOnHold ?? this.isOnHold,
        incomingSdp: clearIncoming ? null : (incomingSdp ?? this.incomingSdp),
        incomingSdpType: clearIncoming ? null : (incomingSdpType ?? this.incomingSdpType),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}
