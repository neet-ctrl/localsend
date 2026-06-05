import 'dart:convert';

import 'package:common/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'hub_device_history_v1';

class HubHistoryDevice {
  final String fingerprint;
  final String alias;
  final String? ip;
  final int port;
  final bool https;
  final DeviceType deviceType;
  final int lastSeen;

  const HubHistoryDevice({
    required this.fingerprint,
    required this.alias,
    this.ip,
    required this.port,
    required this.https,
    required this.deviceType,
    required this.lastSeen,
  });

  Device toDevice() => Device(
    signalingId: null,
    ip: ip,
    version: '1.0',
    port: port,
    https: https,
    fingerprint: fingerprint,
    alias: alias,
    deviceModel: null,
    deviceType: deviceType,
    download: false,
    discoveryMethods: const {},
  );

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'alias': alias,
    'ip': ip,
    'port': port,
    'https': https,
    'deviceType': deviceType.name,
    'lastSeen': lastSeen,
  };

  factory HubHistoryDevice.fromJson(Map<String, dynamic> json) => HubHistoryDevice(
    fingerprint: json['fingerprint'] as String,
    alias: json['alias'] as String,
    ip: json['ip'] as String?,
    port: json['port'] as int? ?? 53317,
    https: json['https'] as bool? ?? false,
    deviceType: DeviceType.values.firstWhere(
      (e) => e.name == json['deviceType'],
      orElse: () => DeviceType.desktop,
    ),
    lastSeen: json['lastSeen'] as int? ?? 0,
  );

  factory HubHistoryDevice.fromDevice(Device d) => HubHistoryDevice(
    fingerprint: d.fingerprint,
    alias: d.alias,
    ip: d.ip,
    port: d.port,
    https: d.https,
    deviceType: d.deviceType,
    lastSeen: DateTime.now().millisecondsSinceEpoch,
  );
}

class HubDeviceHistoryState {
  final Map<String, HubHistoryDevice> devices;

  const HubDeviceHistoryState({this.devices = const {}});

  List<HubHistoryDevice> get sorted {
    final list = devices.values.toList();
    list.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return list;
  }
}

final hubDeviceHistoryProvider =
    NotifierProvider<HubDeviceHistoryNotifier, HubDeviceHistoryState>(
  (ref) => HubDeviceHistoryNotifier(),
);

class HubDeviceHistoryNotifier extends Notifier<HubDeviceHistoryState> {
  SharedPreferences? _prefs;

  @override
  HubDeviceHistoryState init() {
    _load();
    return const HubDeviceHistoryState();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      final map = <String, HubHistoryDevice>{};
      for (final item in list) {
        final d = HubHistoryDevice.fromJson(item as Map<String, dynamic>);
        map[d.fingerprint] = d;
      }
      state = HubDeviceHistoryState(devices: map);
    } catch (_) {}
  }

  Future<void> sawDevice(Device device) async {
    final existing = state.devices[device.fingerprint];
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle: only update state/prefs if IP changed or last-seen is older than 60s.
    // This prevents rebuild loops when called from build().
    if (existing != null &&
        existing.ip == device.ip &&
        (now - existing.lastSeen) < 60000) return;

    final record = HubHistoryDevice.fromDevice(device);
    final map = Map<String, HubHistoryDevice>.from(state.devices);
    map[record.fingerprint] = record;
    state = HubDeviceHistoryState(devices: map);
    await _persist(map);
  }

  Future<void> removeDevice(String fingerprint) async {
    final map = Map<String, HubHistoryDevice>.from(state.devices)
      ..remove(fingerprint);
    state = HubDeviceHistoryState(devices: map);
    await _persist(map);
  }

  Future<void> _persist(Map<String, HubHistoryDevice> map) async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = jsonEncode(map.values.map((d) => d.toJson()).toList());
    await _prefs!.setString(_prefsKey, raw);
  }
}
