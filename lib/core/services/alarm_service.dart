import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alarm sound assets shipped with the app.
abstract final class AlarmSounds {
  /// General alert siren.
  static const String siren = 'sounds/alarm_siren.wav';

  /// Urgent two-tone alarm dedicated to engine overheating.
  static const String engineOverheat = 'sounds/engine_overheat_alarm.wav';
}

/// Plays the in-app alarm while a warning/critical alert is active.
///
/// The caller picks the sound by cause (e.g. the dedicated overheat
/// alarm); the loop runs until [stop] is called and switching assets is
/// seamless. Every call is defensive so audio failures never break the
/// dashboard.
class AlarmService {
  final AudioPlayer _player = AudioPlayer();

  bool _playing = false;
  String? _currentAsset;

  bool get isPlaying => _playing;

  /// The asset currently looping, if any.
  String? get currentAsset => _currentAsset;

  Future<void> start({String asset = AlarmSounds.siren}) async {
    if (_playing && _currentAsset == asset) return;

    if (_playing && _currentAsset != asset) {
      await stop();
    }

    _playing = true;
    _currentAsset = asset;

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(asset), volume: 1.0);
    } catch (e) {
      _playing = false;
      _currentAsset = null;
      debugPrint('ALARM START FAILED: $e');
    }
  }

  Future<void> stop() async {
    _playing = false;
    _currentAsset = null;

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
