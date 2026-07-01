import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/ui/settings/settings_screen.dart';

void main() {
  testWidgets('shows the Voice section and updates rate', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    expect(find.text('Configuración'), findsOneWidget);
    expect(find.text('Voz'), findsOneWidget);
    // Drag the first slider (voice rate) and confirm it persists.
    await tester.drag(find.byType(Slider).first, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(prefs.getDouble('voiceRate'), isNotNull);
  });
}
