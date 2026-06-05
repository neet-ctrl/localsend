import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:localsend_app/util/hub_logger.dart';

/// Plays the ITU-T ringback tone (the sound the caller hears while waiting)
/// on Android via ToneGenerator.TONE_SUP_RINGTONE — exactly the carrier sound.
/// Falls back to a pulsed notification tone on other platforms.
class HubRingbackService {
  HubRingbackService._();
  static final HubRingbackService instance = HubRingbackService._();

  static const _channel = MethodChannel('org.localsend.localsend_app/localsend');

  bool _active = false;
  Timer? _pulseTimer;

  Future<void> startRingback() async {
    if (_active) return;
    _active = true;
    HubLogger.instance.info(HubLogCategory.calls, 'Ringback started');

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('startRingback');
        return;
      } catch (e) {
        HubLogger.instance.warn(HubLogCategory.calls, 'ToneGenerator ringback failed, falling back: $e');
      }
    }

    // Fallback for non-Android or if MethodChannel fails:
    // Play a short ringtone every 4 seconds to simulate ringback cadence.
    await _pulse();
    _pulseTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_active) await _pulse();
    });
  }

  Future<void> stopRingback() async {
    if (!_active) return;
    _active = false;
    _pulseTimer?.cancel();
    _pulseTimer = null;
    HubLogger.instance.info(HubLogCategory.calls, 'Ringback stopped');

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopRingback');
        return;
      } catch (e) {
        HubLogger.instance.warn(HubLogCategory.calls, 'stopRingback channel error (ignored): $e');
      }
    }
    try {
      await FlutterRingtonePlayer().stop();
    } catch (_) {}
  }

  Future<void> _pulse() async {
    try {
      await FlutterRingtonePlayer().playNotification(looping: false);
    } catch (_) {}
  }
}
