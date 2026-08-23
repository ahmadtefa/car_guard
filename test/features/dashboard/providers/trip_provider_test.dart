import 'package:car_guard/features/dashboard/providers/trip_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for the odometer persistence: closing and reopening
/// the app must never wipe the trip distance — only the reset button does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Boots the provider inside a throwaway container and waits for the
  /// async restore + location probing (which throws in tests and is
  /// swallowed) to settle.
  Future<ProviderContainer> boot(Map<String, Object> initialPrefs) async {
    SharedPreferences.setMockInitialValues(initialPrefs);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(tripProvider, (_, __) {});
    addTearDown(sub.close);

    await Future<void>.delayed(const Duration(milliseconds: 50));

    return container;
  }

  test('restores the saved trip distance when the app reopens', () async {
    final container = await boot(const {'trip_distance_km': 42.5});

    expect(container.read(tripProvider).distanceKm, 42.5);
  });

  test('starts at zero when there is nothing saved yet', () async {
    final container = await boot(const {});

    expect(container.read(tripProvider).distanceKm, 0);
  });

  test('resetTrip persists the zero so a relaunch stays at zero', () async {
    final container = await boot(const {'trip_distance_km': 42.5});

    expect(container.read(tripProvider).distanceKm, 42.5);

    container.read(tripProvider.notifier).resetTrip();
    expect(container.read(tripProvider).distanceKm, 0);

    // The persist write is fire-and-forget; give it a moment to land.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('trip_distance_km'), 0);
  });
}
