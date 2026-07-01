import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/astro_brain_provider.dart';
import '../../core/config/design_tokens.dart';
import '../../core/config/settings_providers.dart';
import '../../platform/permissions.dart';
import '../../voice/neural_voice_installer.dart';
import '../../voice/neural_voice_provider.dart';
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
              // Neural voice: download on demand, then enable.
              Consumer(
                builder: (context, ref, _) {
                  final installState = ref.watch(voiceInstallStateProvider);
                  final installed = settings.neuralVoiceInstalled;
                  final subtitle = installState.maybeWhen(
                    data: (s) => switch (s) {
                      Installing(:final progress) =>
                        progress < 0
                            ? 'Descargando…'
                            : 'Descargando ${(progress * 100).round()}%',
                      InstallError(:final message) => 'Error: $message',
                      Installed() => 'Lista',
                      NotInstalled() =>
                        installed ? 'Instalada' : 'No descargada',
                    },
                    orElse: () => installed ? 'Instalada' : 'No descargada',
                  );
                  return ListTile(
                    title: const Text(
                      'Voz neuronal (offline)',
                      style: TextStyle(color: DesignTokens.ink),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(color: DesignTokens.dim),
                    ),
                    trailing: installed
                        ? null
                        : TextButton(
                            onPressed: () => ref
                                .read(neuralVoiceInstallerProvider)
                                .install(),
                            child: const Text('Descargar'),
                          ),
                  );
                },
              ),
              SettingsSwitchTile(
                label: 'Usar voz neuronal',
                subtitle: 'Requiere descargarla primero',
                value: settings.neuralVoiceEnabled,
                onChanged: settings.neuralVoiceInstalled
                    ? notifier.setNeuralVoiceEnabled
                    : (_) {},
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
          const _MemorySection(),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Permisos',
            children: [
              ListTile(
                title: const Text(
                  'Micrófono',
                  style: TextStyle(color: DesignTokens.ink),
                ),
                trailing: const Icon(Icons.mic, color: DesignTokens.dim),
                onTap: () => const Permissions().requestMicrophone(),
              ),
              ListTile(
                title: const Text(
                  'Notificaciones',
                  style: TextStyle(color: DesignTokens.ink),
                ),
                trailing: const Icon(
                  Icons.notifications,
                  color: DesignTokens.dim,
                ),
                onTap: () => const Permissions().requestNotifications(),
              ),
              ListTile(
                title: const Text(
                  'Ubicación',
                  style: TextStyle(color: DesignTokens.ink),
                ),
                trailing: const Icon(
                  Icons.location_on,
                  color: DesignTokens.dim,
                ),
                onTap: () => const Permissions().requestLocation(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Acerca de',
            children: [
              ListTile(
                title: const Text(
                  'Astro',
                  style: TextStyle(color: DesignTokens.ink),
                ),
                subtitle: Text(
                  'Voz neuronal: '
                  '${settings.neuralVoiceInstalled ? "instalada" : "no instalada"}'
                  ' · Modelo: ${settings.llmModel}',
                  style: const TextStyle(color: DesignTokens.dim),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Memory section: shows the stored-memory count and offers a destructive
/// "clear" with confirmation. Reads the shared memory instance from the brain
/// provider; degrades to a disabled row if memory failed to open.
class _MemorySection extends ConsumerWidget {
  const _MemorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoryAsync = ref.watch(memoryProvider);
    return SettingsSection(
      title: 'Memoria',
      children: [
        memoryAsync.when(
          loading: () => const ListTile(
            title: Text('Memoria', style: TextStyle(color: DesignTokens.ink)),
            trailing: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const ListTile(
            title: Text(
              'Memoria no disponible',
              style: TextStyle(color: DesignTokens.dim),
            ),
          ),
          data: (memory) {
            if (memory == null) {
              return const ListTile(
                title: Text(
                  'Memoria no disponible',
                  style: TextStyle(color: DesignTokens.dim),
                ),
              );
            }
            return FutureBuilder<int>(
              future: memory.count(),
              builder: (context, snap) {
                final n = snap.data ?? 0;
                return ListTile(
                  title: const Text(
                    'Recuerdos guardados',
                    style: TextStyle(color: DesignTokens.ink),
                  ),
                  subtitle: Text(
                    '$n',
                    style: const TextStyle(color: DesignTokens.dim),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¿Borrar la memoria?'),
                          content: const Text(
                            'Astro olvidará todo lo que recuerda de ti.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Borrar'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await memory.clearAll();
                        // Rebuild the FutureBuilder by nudging the provider.
                        ref.invalidate(memoryProvider);
                      }
                    },
                    child: const Text('Borrar'),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
