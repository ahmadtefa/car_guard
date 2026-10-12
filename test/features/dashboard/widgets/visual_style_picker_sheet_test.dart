import 'package:car_guard/core/models/app_settings.dart';
import 'package:car_guard/features/dashboard/widgets/visual_style_picker_sheet.dart';
import 'package:car_guard/features/settings/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier([this._initial = const AppSettings(dashboardStyleName: 'racing')]);

  AppSettings _initial;

  @override
  Future<AppSettings> build() async => _initial;

  @override
  Future<void> save(AppSettings settings) async {
    _initial = settings;
    state = AsyncData(settings);
  }
}

Widget _buildTestApp({
  required Widget child,
  AppSettings settings = const AppSettings(dashboardStyleName: 'racing'),
  TextDirection textDirection = TextDirection.ltr,
  Size size = const Size(390, 844),
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
    ],
    child: MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('VisualStylePickerSheet metadata & 12 styles', () {
    test('contains all 12 supported dashboard styles from AppSettings without omissions', () {
      expect(kDashboardStyles.length, 12);
      final ids = kDashboardStyles.map((s) => s.id).toList();
      expect(ids, containsAll(AppSettings.dashboardStyleNames));
      expect(AppSettings.dashboardStyleNames, containsAll(ids));
    });

    test('all styles belong to valid categories with valid labels', () {
      const allowedCategories = {'cockpit', 'scifi', 'luxury', 'minimal'};
      for (final style in kDashboardStyles) {
        expect(
          allowedCategories.contains(style.category),
          isTrue,
          reason: 'Style ${style.id} has invalid category: ${style.category}',
        );
        expect(style.badgeText.isNotEmpty, isTrue);
        expect(style.englishSubtitle.isNotEmpty, isTrue);
      }
    });

    test('categories partition the 12 styles cleanly', () {
      final cockpit = kDashboardStyles.where((s) => s.category == 'cockpit').map((s) => s.id).toList();
      final scifi = kDashboardStyles.where((s) => s.category == 'scifi').map((s) => s.id).toList();
      final luxury = kDashboardStyles.where((s) => s.category == 'luxury').map((s) => s.id).toList();
      final minimal = kDashboardStyles.where((s) => s.category == 'minimal').map((s) => s.id).toList();

      expect(cockpit, ['racing', 'sporty', 'sweeper', 'premium']);
      expect(scifi, ['ring', 'led', 'needle', 'combo']);
      expect(luxury, ['rose', 'lavender', 'flamingo']);
      expect(minimal, ['big_numbers']);
      expect(cockpit.length + scifi.length + luxury.length + minimal.length, 12);
    });
  });

  group('VisualStylePickerSheet widget rendering & interaction', () {
    testWidgets('renders all 12 styles in English and shows active badge on current style', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const VisualStylePickerSheet(),
          settings: const AppSettings(dashboardStyleName: 'racing'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('Dashboard style'), findsOneWidget);
      expect(find.text('15 custom cockpit skins'), findsOneWidget);

      // Verify active badge on 'racing'
      expect(find.text('Active'), findsOneWidget);

      // Verify category filter chips
      expect(find.text('All (12)'), findsOneWidget);
      expect(find.text('Cockpit'), findsOneWidget);
      expect(find.text('Sci-Fi'), findsOneWidget);
      expect(find.text('Luxury'), findsOneWidget);
      expect(find.text('Minimal'), findsOneWidget);

      // Verify some styles are visible initially in the grid
      expect(find.text('Racing'), findsOneWidget);
      expect(find.text('Sporty gauges'), findsOneWidget);
    });

    testWidgets('renders in Arabic RTL with localized labels', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          textDirection: TextDirection.rtl,
          child: const VisualStylePickerSheet(),
          settings: const AppSettings(
            languageName: 'ar',
            dashboardStyleName: 'racing',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Arabic title and subtitle
      expect(find.text('شكل الداشبورد'), findsOneWidget);
      expect(find.text('15 نمطاً مخصصاً للمقصورة'), findsOneWidget);

      // Verify Arabic category chips
      expect(find.text('الكل (12)'), findsOneWidget);
      expect(find.text('رياضي'), findsOneWidget);
      expect(find.text('رقمي'), findsOneWidget);
      expect(find.text('فخامة'), findsOneWidget);
      expect(find.text('أرقام'), findsWidgets);

      // Verify active badge in Arabic
      expect(find.text('النشط'), findsOneWidget);

      // Verify Arabic style names
      expect(find.text('سباق'), findsOneWidget);
      expect(find.text('سبورت'), findsOneWidget);
    });

    testWidgets('filtering by category filters the visible styles and can return to All', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const VisualStylePickerSheet(),
          settings: const AppSettings(dashboardStyleName: 'racing'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Luxury' category chip
      await tester.ensureVisible(find.text('Luxury'));
      await tester.tap(find.text('Luxury'));
      await tester.pumpAndSettle();

      // Luxury contains Rose elegance, Lavender pearl, Flamingo
      expect(find.text('Rose elegance'), findsOneWidget);
      expect(find.text('Lavender pearl'), findsOneWidget);
      expect(find.text('Flamingo'), findsOneWidget);
      // Racing is not in luxury
      expect(find.text('Racing'), findsNothing);

      // Tap 'Minimal' category chip
      await tester.ensureVisible(find.text('Minimal'));
      await tester.tap(find.text('Minimal'));
      await tester.pumpAndSettle();

      expect(find.text('Big Numbers'), findsOneWidget);
      expect(find.text('Rose elegance'), findsNothing);

      // Tap 'All (12)' to reset
      await tester.ensureVisible(find.text('All (12)'));
      await tester.tap(find.text('All (12)'));
      await tester.pumpAndSettle();

      expect(find.text('Racing'), findsOneWidget);
    });

    testWidgets('tapping a style card updates settingsProvider to that style', (tester) async {
      final fakeNotifier = _FakeSettingsNotifier(const AppSettings(dashboardStyleName: 'racing'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => fakeNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VisualStylePickerSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Sporty gauges' card
      await tester.tap(find.text('Sporty gauges'));
      await tester.pumpAndSettle();

      // Verify the notifier received the change
      expect(fakeNotifier._initial.dashboardStyleName, 'sporty');
    });

    testWidgets('adapts smoothly to narrow screens (~320dp width) without overflow', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          size: const Size(320, 568),
          child: const VisualStylePickerSheet(),
        ),
      );
      await tester.pumpAndSettle();

      // Should render without throwing layout exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('adapts smoothly to landscape / tablet widths (800dp width)', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          size: const Size(800, 600),
          child: const VisualStylePickerSheet(),
        ),
      );
      await tester.pumpAndSettle();

      // Should render without throwing layout exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('Apply Style button pops the sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => _FakeSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const VisualStylePickerSheet(),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(VisualStylePickerSheet), findsOneWidget);

      // Tap 'Apply Style'
      await tester.tap(find.text('Apply Style'));
      await tester.pumpAndSettle();

      // Sheet should be popped
      expect(find.byType(VisualStylePickerSheet), findsNothing);
    });
  });
}
