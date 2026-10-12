import 'dart:convert';

import 'package:car_guard/core/models/app_settings.dart';
import 'package:car_guard/core/models/license_models.dart';
import 'package:car_guard/core/models/reading_sample.dart';
import 'package:car_guard/core/providers/device_status_provider.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:car_guard/core/services/storage_service.dart';
import 'package:car_guard/features/dashboard/providers/readings_history_provider.dart';
import 'package:car_guard/features/license/models/license_state.dart';
import 'package:car_guard/features/license/providers/license_provider.dart';
import 'package:car_guard/features/settings/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

class _TestLicenseNotifier extends Notifier<LicenseState> {
  _TestLicenseNotifier(this.initialState);

  final LicenseState initialState;

  @override
  LicenseState build() => initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sample = ReadingSample(
    timestamp: DateTime.utc(2026, 10, 12, 20),
    engineTemperature: 88,
    batteryVoltage: 12.6,
  );

  Future<ProviderContainer> createContainer(LicenseState license) async {
    SharedPreferences.setMockInitialValues({
      ReadingsHistoryNotifier.storageKey: jsonEncode([sample.toJson()]),
    });
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(() => _TestSettingsNotifier()),
        licenseProvider.overrideWith(() => _TestLicenseNotifier(license)),
        deviceStatusProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    container.read(readingsHistoryProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return container;
  }

  test('keeps saved readings while an ACTIVE license is being rechecked', () async {
    final container = await createContainer(
      const LicenseState(
        status: LicenseDeviceStatus.active,
        checkStatus: LicenseCheckStatus.checking,
      ),
    );
    addTearDown(container.dispose);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReadingsHistoryNotifier.storageKey), isNotNull);
  });

  test('deletes saved readings after an authoritative LOCKED response', () async {
    final container = await createContainer(
      const LicenseState(
        status: LicenseDeviceStatus.locked,
        checkStatus: LicenseCheckStatus.noLicense,
      ),
    );
    addTearDown(container.dispose);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReadingsHistoryNotifier.storageKey), isNull);
  });
}
