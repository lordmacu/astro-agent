import 'package:flutter/material.dart';

import 'core/config/design_tokens.dart';
import 'ui/pet_screen.dart';

/// Root widget. Single screen: Chispa on the dashboard.
class ChispaApp extends StatelessWidget {
  const ChispaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chispa',
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
