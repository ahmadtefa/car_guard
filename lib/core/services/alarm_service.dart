import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays the in-app alarm siren while a warning/critical alert is active.
///
/// The siren loops until [stop] is called; every call is defensive so audio
/// failures never break the dashboard.
class AlarmService {
  final AudioPlayer _player = AudioPlayer();

  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> start() async {
    if (_playing) return;

    _playing = true;

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        AssetSource('sounds/alarm_siren.wav'),
        volume: 1.0,
      );
    } catch (e) {
      _playing = false;
      debugPrint('ALARM START FAILED: $e');
    }
  }

  Future<void> stop() async {
    _playing = false;

    try {
      await _player.stop();
    } catch (_) {
      // Nothing meaningful to do if stopping fails.
    }
  }

  Future<void> dispose() async {
    _playing = false;

    try {
      await _player.dispose();
    } catch (_) {
      // Nothing meaningful to do if disposal fails.
    }
  }
}

final alarmServiceProvider = Provider<AlarmService>((ref) {
  final service = AlarmService();

  ref.onDispose(service.dispose);

  return service;
});
