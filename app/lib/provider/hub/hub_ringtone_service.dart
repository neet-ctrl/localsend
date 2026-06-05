import 'dart:io';

import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class HubRingtoneService {
  HubRingtoneService._();
  static final HubRingtoneService instance = HubRingtoneService._();

  bool _active = false;

  Future<void> start() async {
    if (_active) return;
    _active = true;
    if (Platform.isAndroid) {
      await FlutterRingtonePlayer.playRingtone(looping: true);
    }
  }

  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    if (Platform.isAndroid) {
      await FlutterRingtonePlayer.stop();
    }
  }
}
