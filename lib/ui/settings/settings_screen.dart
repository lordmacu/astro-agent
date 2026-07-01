import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/settings_providers.dart';
import 'settings_widgets.dart';

/// The single place where all runtime configuration lives. Grows section by
/// section (voice, AI, wake word, memory, permissions, about) across the plan.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          SettingsSection(
            title: 'Voz',
            children: [
              SettingsSliderTile(
                label: 'Velocidad',
                value: settings.voiceRate,
                min: 0.3,
                max: 1.0,
                onChanged: notifier.setVoiceRate,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
