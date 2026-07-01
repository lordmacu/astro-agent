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

  testWidgets('AI section: Modelo dropdown shows presets', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    // The Modelo label should be present via a ListTile.
    expect(find.text('Modelo'), findsOneWidget);
    // The dropdown button for the model should be present.
    expect(find.byType(DropdownButton<String>), findsWidgets);
  });

  testWidgets('AI section: selecting a model preset persists it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    // Scroll to make IA section visible.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Open the Modelo dropdown by tapping it.
    // The model dropdown is the one inside the 'Modelo' ListTile.
    final modelDropdown = find.descendant(
      of: find.ancestor(
        of: find.text('Modelo'),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(DropdownButton<String>),
    );
    expect(modelDropdown, findsOneWidget);

    await tester.tap(modelDropdown);
    await tester.pumpAndSettle();

    // The dropdown menu should show 'gpt-4o-mini'.
    final target = find.text('gpt-4o-mini').last;
    expect(target, findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(prefs.getString('llmModel'), 'gpt-4o-mini');
  });

  testWidgets('AI section: custom model shows text field', (tester) async {
    SharedPreferences.setMockInitialValues({'llmModel': 'my-custom-model'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    // When model is not in presets, the custom text tile should appear.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Modelo personalizado'), findsOneWidget);
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
