import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:astro/sensors/navigation/nav_service.dart';
import 'package:astro/ui/settings/settings_screen.dart';

class _FakeNavControl implements NavControl {
  _FakeNavControl(this._granted);
  final bool _granted;
  int openCalls = 0;
  @override
  Future<bool> hasPermission() async => _granted;
  @override
  Future<void> openSettings() async => openCalls++;
}

void main() {
  testWidgets('enabling nav without access opens settings', (tester) async {
    SharedPreferences.setMockInitialValues({'navListenerEnabled': false});
    final prefs = await SharedPreferences.getInstance();
    final fake = _FakeNavControl(false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLangProvider.overrideWithValue(AppLang.es),
          navControlProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    // Scroll the switch into view, then toggle it on.
    final tile = find.widgetWithText(SwitchListTile, 'Navegación (Maps)');
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(prefs.getBool('navListenerEnabled'), true);
    expect(fake.openCalls, 1);
  });

  testWidgets(
    'nav tile shows "Sin acceso" subtitle when enabled but permission denied',
    (tester) async {
      // navListenerEnabled = true, permission = false → should show warning text.
      SharedPreferences.setMockInitialValues({'navListenerEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final fake = _FakeNavControl(false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            deviceLangProvider.overrideWithValue(AppLang.es),
            navControlProvider.overrideWithValue(fake),
            // Override the permission provider directly to resolve immediately.
            navPermissionProvider.overrideWith((_) async => false),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll nav tile into view.
      final tile = find.widgetWithText(SwitchListTile, 'Navegación (Maps)');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Sin acceso a notificaciones — toca para conceder'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'nav tile shows normal subtitle when enabled with permission granted',
    (tester) async {
      SharedPreferences.setMockInitialValues({'navListenerEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final fake = _FakeNavControl(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            deviceLangProvider.overrideWithValue(AppLang.es),
            navControlProvider.overrideWithValue(fake),
            navPermissionProvider.overrideWith((_) async => true),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(SwitchListTile, 'Navegación (Maps)');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Reaccionar a las indicaciones de Google Maps'),
        findsOneWidget,
      );
    },
  );
}
