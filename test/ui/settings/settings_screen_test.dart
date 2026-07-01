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
    // The Modelo dropdown (inside its ListTile) should be present.
    final modelDropdown = find.descendant(
      of: find.ancestor(
        of: find.text('Modelo'),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(DropdownButton<String>),
    );
    expect(modelDropdown, findsOneWidget);
  });

  testWidgets('AI section: selecting Personalizado reveals custom text field', (
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

    // Scroll to make the IA section visible.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Custom field must NOT be visible before selecting it.
    expect(find.text('Modelo personalizado'), findsNothing);

    // Tap the Modelo dropdown (NOT the Idioma one).
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

    // Select "Personalizado…" from the menu.
    final customItem = find.text('Personalizado…').last;
    expect(customItem, findsOneWidget);
    await tester.tap(customItem);
    await tester.pumpAndSettle();

    // The stored model value must NOT be cleared.
    // The custom text field must NOW be visible.
    expect(find.text('Modelo personalizado'), findsOneWidget);
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
    // Tall viewport so the lazy ListView builds enough sections to reach the
    // wake-word tile without depending on scroll offsets (the screen grows as
    // more config sections are added above it).
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    // Match by prefix: the label embeds the configurable wake word
    // ('Palabra clave «<word>»'), so don't hard-code the word here.
    final tile = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          ((w.title as Text).data ?? '').startsWith('Palabra clave'),
    );
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    expect(prefs.getBool('wakeWordEnabled'), false);
  });
}
