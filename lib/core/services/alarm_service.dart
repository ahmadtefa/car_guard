import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alarm sound assets shipped with the app.
abstract final class AlarmSounds {
  /// General alert siren (looping).
  static const String siren = 'sounds/alarm_siren.wav';

  /// The user's engine-overheat sound file (plays once per cycle).
  static const String engineOverheat = 'sounds/engine_overheat_alarm.mp3';

  /// Very loud urgent burst (~2 s) played right after the overheat file,
  /// then the file again, alternating until the alert clears.
  static const String urgentBurst = 'sounds/urgent_burst_2s.wav';
}

/// Plays the in-app alarm while a warning/critical alert is active.
///
/// The general siren loops continuously. The engine-overheat alarm runs a
/// cycle instead: the user's sound file plays once, then a 2-second very
/// loud urgent burst, then the file again — alternating until [stop] is
/// called (i.e. until the temperature drops). Every call is defensive so
/// audio failures never break the dashboard.
class AlarmService {
  AlarmService() {
    _completionSubscription = _player.onPlayerComplete.listen((_) {
      _onPlaybackComplete();
    });
  }

  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<void>? _completionSubscription;

  bool _playing = false;
  bool _cycling = false;
  bool _burstPlaying = false;
  String? _currentAsset;

  bool get isPlaying => _playing;

  /// The asset the cycle was started with, if any.
  String? get currentAsset => _currentAsset;

  Future<void> start({String asset = AlarmSounds.siren}) async {
    if (_playing && _currentAsset == asset) return;

    if (_playing && _currentAsset != asset) {
      await stop();
    }

    _playing = true;
    _currentAsset = asset;
    _burstPlaying = false;

    // The overheat alarm alternates file -> urgent burst -> file...
    _cycling = asset == AlarmSounds.engineOverheat;

    try {
      await _player.setReleaseMode(
        _cycling ? ReleaseMode.stop : ReleaseMode.loop,
      );

      await _player.play(AssetSource(asset), volume: 1.0);
    } catch (e) {
      debugPrint('ALARM START FAILED ($asset): $e');

      // Fall back to the looping siren when the requested asset is
      // missing or unreadable, so an alert is never silent.
      if (asset != AlarmSounds.siren) {
        try {
          _cycling = false;
          _currentAsset = AlarmSounds.siren;

          await _player.setReleaseMode(ReleaseMode.loop);
          await _player.play(
            AssetSource(AlarmSounds.siren),
            volume: 1.0,
          );
          return;
        } catch (_) {
          // Give up quietly.
        }
      }

      _playing = false;
      _cycling = false;
      _currentAsset = null;
    }
  }

  Future<void> _onPlaybackComplete() async {
    if (!_playing || !_cycling) return;

    // Alternate: file finished -> burst; burst finished -> file.
    final next =
        _burstPlaying ? AlarmSounds.engineOverheat : AlarmSounds.urgentBurst;

    _burstPlaying = !_burstPlaying;

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource(next), volume: 1.0);
    } catch (e) {
      debugPrint('ALARM CYCLE STEP FAILED: $e');
    }
  }

  Future<void> stop() async {
    _playing = false;
    _cycling = false;
    _burstPlaying = false;
    _currentAsset = null;

    try {
      await _player.stop();
    } catch (_) {
      // Nothing meaningful to do if stopping fails.
    }
  }

  Future<void> dispose() async {
    await _completionSubscription?.cancel();
    _completionSubscription = null;

    await stop();

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
