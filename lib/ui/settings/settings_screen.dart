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
          SettingsSection(
            title: 'IA',
            children: [
              SettingsTextTile(
                label: 'Modelo',
                value: settings.llmModel,
                hint: 'MiniMax-M3',
                onSubmitted: notifier.setLlmModel,
              ),
              SettingsTextTile(
                label: 'API key del LLM',
                value: settings.llmApiKey,
                obscure: true,
                onSubmitted: notifier.setLlmApiKey,
              ),
              SettingsTextTile(
                label: 'API key de búsqueda web',
                value: settings.searchApiKey,
                obscure: true,
                onSubmitted: notifier.setSearchApiKey,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Wake word y sensores',
            children: [
              SettingsSwitchTile(
                label: 'Palabra clave «Astro»',
                subtitle: 'Escuchar siempre para responder por voz',
                value: settings.wakeWordEnabled,
                onChanged: notifier.setWakeWordEnabled,
              ),
              SettingsSliderTile(
                label: 'Sensibilidad',
                value: settings.wakeWordSensitivity,
                min: 0.0,
                max: 1.0,
                onChanged: notifier.setWakeWordSensitivity,
              ),
              SettingsSwitchTile(
                label: 'Navegación (Maps)',
                subtitle: 'Reaccionar a las indicaciones de Google Maps',
                value: settings.navListenerEnabled,
                onChanged: notifier.setNavListenerEnabled,
              ),
              SettingsSwitchTile(
                label: 'Brillo automático',
                subtitle: 'Ajustar el brillo con la luz del ambiente',
                value: settings.autoBrightnessEnabled,
                onChanged: notifier.setAutoBrightnessEnabled,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
