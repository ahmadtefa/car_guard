import 'package:car_guard/core/models/app_settings.dart';
import 'package:car_guard/core/models/license_models.dart';
import 'package:car_guard/features/license/widgets/license_status_banner.dart';
import 'package:car_guard/features/settings/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> build() async => settings;
}

Future<List<FlutterErrorDetails>> _pumpBanner(
  WidgetTester tester, {
  required String languageName,
  required TextDirection textDirection,
  required Size size,
}) async {
  final overflowErrors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('RenderFlex overflowed')) {
      overflowErrors.add(details);
    }
  };

  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsNotifier(
              AppSettings(languageName: languageName),
            ),
          ),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: textDirection,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: const LicenseStatusBanner(
                status: LicenseCheckStatus.noLicense,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  } finally {
    FlutterError.onError = previousOnError;
  }

  return overflowErrors;
}

void expectBannerTextWithinCard(WidgetTester tester, Finder textFinder) {
  final textBox = tester.renderObject<RenderParagraph>(textFinder);
  final textRect = tester.getRect(textFinder);
  final cardRect = tester.getRect(find.byType(Card));

  expect(textBox.didExceedMaxLines, isFalse);
  expect(textRect.left, greaterThanOrEqualTo(cardRect.left));
  expect(textRect.right, lessThanOrEqualTo(cardRect.right));
  expect(textRect.top, greaterThanOrEqualTo(cardRect.top));
  expect(textRect.bottom, lessThanOrEqualTo(cardRect.bottom));
}

void main() {
  testWidgets('license banner wraps narrow English text without overflow',
      (tester) async {
    final overflowErrors = await _pumpBanner(
      tester,
      languageName: 'en',
      textDirection: TextDirection.ltr,
      size: const Size(220, 360),
    );

    expect(overflowErrors, isEmpty);
    expectBannerTextWithinCard(tester, find.text('No license'));
    expectBannerTextWithinCard(
      tester,
      find.text(
        'The module reported no valid license. Activate a license code to unlock fan and buzzer controls.',
      ),
    );
    expectBannerTextWithinCard(tester, find.text('Open license'));
  });

  testWidgets('license banner wraps narrow Arabic text without overflow',
      (tester) async {
    final overflowErrors = await _pumpBanner(
      tester,
      languageName: 'ar',
      textDirection: TextDirection.rtl,
      size: const Size(220, 420),
    );

    expect(overflowErrors, isEmpty);
    expectBannerTextWithinCard(tester, find.text('لا يوجد ترخيص'));
    expectBannerTextWithinCard(
      tester,
      find.text(
        'الجهاز لم يبلّغ عن ترخيص صالح. فعّل كود الترخيص لفتح أوامر المروحة والجرس.',
      ),
    );
    expectBannerTextWithinCard(tester, find.text('فتح صفحة الترخيص'));
  });
}
