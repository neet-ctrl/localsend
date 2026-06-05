import 'dart:io';

import 'package:flutter/services.dart';

class HubForegroundService {
  static const _channel = MethodChannel('org.localsend.localsend_app/localsend');

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startHubService');
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopHubService');
    } catch (_) {}
  }
}
