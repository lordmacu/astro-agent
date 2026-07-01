import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/design_tokens.dart';
import 'core/l10n/lang_provider.dart';
import 'ui/pet_screen.dart';

/// Root widget. Single screen: Astro on the dashboard. A `WidgetsBindingObserver`
/// refreshes the device language when the system locale changes, so `Auto` stays
/// live. (Native Material-widget localization — `flutter_localizations` — is
/// deferred: it needs a newer `intl` than `enough_mail` currently allows. Our
/// own text/voice/prompt localization flows through `langProvider` regardless.)
class AstroApp extends ConsumerStatefulWidget {
  const AstroApp({super.key});

  @override
  ConsumerState<AstroApp> createState() => _AstroAppState();
}

class _AstroAppState extends ConsumerState<AstroApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // System language changed → re-resolve the device language.
    ref.invalidate(deviceLangProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DesignTokens.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: DesignTokens.bgBottomFallback,
      ),
      home: const PetScreen(),
    );
  }
}
