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

  testWidgets('AI section persists the model on submit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    final modelField = find.widgetWithText(TextField, 'Modelo');
    expect(modelField, findsOneWidget);
    await tester.enterText(modelField, 'MiniMax-M3-Turbo');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(prefs.getString('llmModel'), 'MiniMax-M3-Turbo');
  });

  testWidgets('wake word toggle persists', (tester) async {
    SharedPreferences.setMockInitialValues({'wakeWordEnabled': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    // Scroll to reveal the wake-word tile (the Voz section now has extra items
    // above it that push the wake-word section below the initial viewport).
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(SwitchListTile, 'Palabra clave «Astro»');
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    await tester.pump();
    expect(prefs.getBool('wakeWordEnabled'), false);
  });
}
