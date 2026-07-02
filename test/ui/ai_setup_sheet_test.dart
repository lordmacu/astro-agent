import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:astro/ui/ai_setup_sheet.dart';

void main() {
  testWidgets('saving a key persists it and returns true', (tester) async {
    // Seed a preset model so the picker is deterministic (not custom mode),
    // independent of the app's default model.
    SharedPreferences.setMockInitialValues({'llmModel': 'MiniMax-M3'});
    final prefs = await SharedPreferences.getInstance();
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLangProvider.overrideWithValue(AppLang.es),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async => result = await showAiSetupSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The hint and title render (model preset + provider hint both mention
    // MiniMax, so assert there are at least both, not exactly one).
    expect(find.textContaining('MiniMax'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 'sk-test-123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(result, true);
    expect(prefs.getString('llmApiKey'), 'sk-test-123');
  });

  testWidgets('dismissing without saving returns false', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLangProvider.overrideWithValue(AppLang.es),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async => result = await showAiSetupSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Tap the scrim to dismiss.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, false);
    expect(prefs.getString('llmApiKey'), isNull);
  });
}
