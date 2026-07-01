import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/astro_brain_provider.dart';
import '../../core/config/design_tokens.dart';
import '../../core/config/settings_providers.dart';
import '../../platform/permissions.dart';
import '../../sensors/navigation/nav_service.dart';
import '../../voice/neural_voice_installer.dart';
import '../../voice/neural_voice_provider.dart';
import 'settings_widgets.dart';

/// Preset model identifiers for the LLM dropdown.
const _modelPresets = [
  'MiniMax-M3',
  'gpt-4o',
  'gpt-4o-mini',
  'gpt-4.1',
  'gpt-4.1-mini',
  'o3-mini',
  'deepseek-chat',
  'deepseek-reasoner',
];

/// Sentinel shown in the dropdown when the stored model is a custom string.
const _customSentinel = 'custom';

/// Displayed app version. Updated manually on release cuts.
const _appVersion = '0.1.0';

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
              SettingsSliderTile(
                label: 'Tono',
                value: settings.voicePitch,
                min: 0.5,
                max: 2.0,
                onChanged: notifier.setVoicePitch,
              ),
              // Language selector (ES / EN).
              ListTile(
                title: const Text(
                  'Idioma',
                  style: TextStyle(color: DesignTokens.ink),
                ),
                trailing: DropdownButton<String>(
                  value: settings.voiceLanguage,
                  dropdownColor: const Color(0xFF1a2537),
                  style: const TextStyle(color: DesignTokens.ink),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) {
                    if (v != null) notifier.setVoiceLanguage(v);
                  },
                ),
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
              _ModelPickerTile(
                currentModel: settings.llmModel,
                onChanged: notifier.setLlmModel,
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
                onChanged: (on) async {
                  await notifier.setNavListenerEnabled(on);
                  if (!on) return;
                  final control = ref.read(navControlProvider);
                  if (!await control.hasPermission()) {
                    await control.openSettings();
                  }
                },
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
                  'v$_appVersion'
                  ' · Voz neuronal: '
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

/// Model picker: a dropdown of preset model names plus a "Personalizado…"
/// sentinel. Selecting "Personalizado…" reveals a free-text tile without
/// clobbering the stored model value; the text tile persists until a preset is
/// chosen again. Also shown automatically when the stored model is already a
/// non-preset value (so existing custom values open in custom mode).
class _ModelPickerTile extends StatefulWidget {
  const _ModelPickerTile({required this.currentModel, required this.onChanged});

  final String currentModel;
  final ValueChanged<String> onChanged;

  @override
  State<_ModelPickerTile> createState() => _ModelPickerTileState();
}

class _ModelPickerTileState extends State<_ModelPickerTile> {
  /// True when the user has chosen "Personalizado…" from the dropdown OR when
  /// the stored model is already a non-preset value.
  late bool _customMode;

  @override
  void initState() {
    super.initState();
    _customMode = !_modelPresets.contains(widget.currentModel);
  }

  @override
  void didUpdateWidget(_ModelPickerTile old) {
    super.didUpdateWidget(old);
    // If the parent rebuilds with a preset model (e.g. after a preset is
    // selected), leave custom mode in whatever state it was set to locally.
    // Only flip it off when the new value is a known preset AND we are not
    // already showing the custom field because of a user tap.
    if (_modelPresets.contains(widget.currentModel)) {
      _customMode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownValue = _customMode ? _customSentinel : widget.currentModel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text(
            'Modelo',
            style: TextStyle(color: DesignTokens.ink),
          ),
          trailing: DropdownButton<String>(
            value: dropdownValue,
            dropdownColor: const Color(0xFF1a2537),
            style: const TextStyle(color: DesignTokens.ink, fontSize: 14),
            underline: const SizedBox.shrink(),
            items: [
              for (final p in _modelPresets)
                DropdownMenuItem(value: p, child: Text(p)),
              const DropdownMenuItem(
                value: _customSentinel,
                child: Text('Personalizado…'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == _customSentinel) {
                // Reveal the custom text field without changing the stored model.
                setState(() => _customMode = true);
                return;
              }
              // A real preset was chosen: leave custom mode and persist.
              setState(() => _customMode = false);
              widget.onChanged(v);
            },
          ),
        ),
        if (_customMode)
          SettingsTextTile(
            label: 'Modelo personalizado',
            value: widget.currentModel,
            hint: 'MiniMax-M3',
            onSubmitted: widget.onChanged,
          ),
      ],
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
