import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_lang.dart';
import '../../core/l10n/lang_provider.dart';

import '../../brain/astro_brain_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/design_tokens.dart';
import '../../core/config/settings_providers.dart';
import '../../core/config/tool_catalog.dart';
import '../../core/config/tool_prefs.dart';
import '../../platform/permissions.dart';
import '../../platform/smtp_store.dart';
import '../../sensors/navigation/nav_service.dart';
import '../../voice/neural_voice_installer.dart';
import '../../voice/neural_voice_provider.dart';
import '../../voice/wake_word_provider.dart';
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
          _languageSection(ref),
          const SizedBox(height: 24),
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
          const _EmailSection(),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Wake word y sensores',
            children: [
              SettingsSwitchTile(
                label: 'Palabra clave «${settings.wakeWord}»',
                subtitle: 'Escuchar siempre para responder por voz',
                value: settings.wakeWordEnabled,
                onChanged: notifier.setWakeWordEnabled,
              ),
              SettingsTextTile(
                label: 'Frase para despertar',
                hint: 'hola astro',
                value: settings.wakeWord,
                onSubmitted: (v) async {
                  await notifier.setWakeWord(v);
                  // Push the new phrase to the always-on native engine now.
                  await ref
                      .read(wakeWordProvider)
                      .setKeyword(ref.read(settingsProvider).wakeWord);
                },
              ),
              SettingsSliderTile(
                label: 'Sensibilidad',
                value: settings.wakeWordSensitivity,
                min: 0.0,
                max: 1.0,
                onChanged: (v) async {
                  await notifier.setWakeWordSensitivity(v);
                  // Retune the always-on native confidence gate live.
                  await ref
                      .read(wakeWordProvider)
                      .setSensitivity(
                        ref.read(settingsProvider).wakeWordSensitivity,
                      );
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final permAsync = ref.watch(navPermissionProvider);
                  final hasPermission = permAsync.valueOrNull ?? true;
                  final subtitle = settings.navListenerEnabled && !hasPermission
                      ? 'Sin acceso a notificaciones — toca para conceder'
                      : 'Reaccionar a las indicaciones de Google Maps';
                  return SettingsSwitchTile(
                    label: 'Navegación (Maps)',
                    subtitle: subtitle,
                    value: settings.navListenerEnabled,
                    onChanged: (on) async {
                      await notifier.setNavListenerEnabled(on);
                      if (!on) return;
                      final control = ref.read(navControlProvider);
                      if (!await control.hasPermission()) {
                        await control.openSettings();
                        ref.invalidate(navPermissionProvider);
                      }
                    },
                  );
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
          const _ToolsSection(),
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

  /// Language selector: Auto (follow the device), Español, or English.
  Widget _languageSection(WidgetRef ref) {
    final pref = ref.watch(langPrefProvider);
    final lang = ref.watch(langProvider);
    String label(LangPref p) => switch (p) {
      LangPref.auto => lang == AppLang.es ? 'Automático' : 'Automatic',
      LangPref.es => 'Español',
      LangPref.en => 'English',
    };
    return SettingsSection(
      title: lang == AppLang.es ? 'Idioma' : 'Language',
      children: [
        for (final p in LangPref.values)
          RadioListTile<LangPref>(
            title: Text(
              label(p),
              style: const TextStyle(color: DesignTokens.ink),
            ),
            value: p,
            groupValue: pref,
            activeColor: DesignTokens.accent,
            onChanged: (v) {
              if (v != null) ref.read(langPrefProvider.notifier).set(v);
            },
          ),
      ],
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

/// Tools section: one switch per brain tool the driver can turn on/off. A
/// disabled tool is dropped from the brain (the model can't call it). When an
/// enabled tool needs an OS permission it lacks, a tappable "grant" line shows.
class _ToolsSection extends StatelessWidget {
  const _ToolsSection();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Herramientas',
      children: [for (final info in kToolCatalog) _ToolTile(info: info)],
    );
  }
}

/// One tool row: title + description + enable switch, plus a permission prompt
/// when the tool is on but its permission isn't granted. Tracks its own
/// permission status and re-checks after a request.
class _ToolTile extends ConsumerStatefulWidget {
  const _ToolTile({required this.info});

  final ToolInfo info;

  @override
  ConsumerState<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends ConsumerState<_ToolTile> {
  /// null = unknown/checking; true/false once resolved. Null for permissionless
  /// tools (nothing to show).
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final perm = widget.info.permission;
    if (perm == null) return;
    final ok = await perm.status.isGranted;
    if (mounted) setState(() => _granted = ok);
  }

  Future<void> _requestPermission() async {
    final perm = widget.info.permission;
    if (perm == null) return;
    final status = await perm.request();
    if (mounted) setState(() => _granted = status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final enabled = !ref.watch(toolPrefsProvider).contains(info.name);
    final needsGrant =
        enabled && info.permission != null && _granted == false;

    return ListTile(
      title: Text(info.label, style: const TextStyle(color: DesignTokens.ink)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.subtitle,
            style: const TextStyle(color: DesignTokens.dim),
          ),
          if (needsGrant)
            InkWell(
              onTap: _requestPermission,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Falta permiso de ${info.permissionLabel} — toca para conceder',
                  style: const TextStyle(
                    color: Color(0xFFFF4D57),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      trailing: Switch(
        value: enabled,
        onChanged: (on) async {
          await ref.read(toolPrefsProvider.notifier).setEnabled(info.name, on);
          // Turning a tool on is a good moment to check its permission.
          if (on) await _refreshPermission();
        },
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
            // Reactive count: updates on its own when a conversation stores a
            // new memory (the extractor invalidates memoryCountProvider).
            final n = ref.watch(memoryCountProvider).valueOrNull ?? 0;
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
                    ref.invalidate(memoryCountProvider); // refresh the counter
                  }
                },
                child: const Text('Borrar'),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// SMTP settings for the send_email tool. Self-contained: loads and saves its
/// own `SmtpStore` (kept out of the main settings so the credentials stay
/// isolated). Each field commits on submit. For Gmail: smtp.gmail.com : 587,
/// your address as the user, and a 16-char app password (needs 2FA on).
class _EmailSection extends StatefulWidget {
  const _EmailSection();

  @override
  State<_EmailSection> createState() => _EmailSectionState();
}

class _EmailSectionState extends State<_EmailSection> {
  static const _store = SmtpStore();

  final _host = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _from = TextEditingController();
  final _imapHost = TextEditingController();
  final _imapPort = TextEditingController();
  bool _loaded = false;
  bool _obscure = true;

  List<TextEditingController> get _all => [
    _host,
    _port,
    _user,
    _pass,
    _from,
    _imapHost,
    _imapPort,
  ];

  @override
  void initState() {
    super.initState();
    _store.load().then((c) {
      if (!mounted) return;
      _host.text = c.host;
      _port.text = c.port.toString();
      _user.text = c.username;
      _pass.text = c.password;
      _from.text = c.fromName;
      _imapHost.text = c.imapHost;
      _imapPort.text = c.imapPort.toString();
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openAppPasswordHelp() async {
    final uri = Uri.parse('https://myaccount.google.com/apppasswords');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pude abrir el enlace.')));
    }
  }

  Future<void> _save() async {
    await _store.save(
      SmtpConfig(
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 587,
        username: _user.text.trim(),
        password: _pass.text,
        fromName: _from.text.trim(),
        imapHost: _imapHost.text.trim(),
        imapPort: int.tryParse(_imapPort.text.trim()) ?? 993,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Correo guardado')));
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure && _obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: DesignTokens.ink),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: DesignTokens.dim),
          suffixIcon: obscure
              ? IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    color: DesignTokens.dim,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SettingsSection(
        title: 'Email (SMTP)',
        children: [
          ListTile(
            title: Text('Cargando…', style: TextStyle(color: DesignTokens.dim)),
          ),
        ],
      );
    }
    return SettingsSection(
      title: 'Email (SMTP)',
      children: [
        _field('Servidor SMTP', _host, hint: 'smtp.gmail.com'),
        _field('Puerto', _port, hint: '587', keyboard: TextInputType.number),
        _field(
          'Usuario (correo)',
          _user,
          hint: 'tucorreo@gmail.com',
          keyboard: TextInputType.emailAddress,
        ),
        _field('Contraseña o app password', _pass, obscure: true),
        ListTile(
          dense: true,
          leading: const Icon(
            Icons.open_in_new,
            color: DesignTokens.accent,
            size: 18,
          ),
          title: const Text(
            'Crear app password de Gmail',
            style: TextStyle(color: DesignTokens.accent, fontSize: 13),
          ),
          subtitle: const Text(
            'Requiere verificación en dos pasos. Se abre en el navegador.',
            style: TextStyle(color: DesignTokens.dim, fontSize: 11),
          ),
          onTap: _openAppPasswordHelp,
        ),
        _field('Nombre del remitente (opcional)', _from, hint: 'Astro'),
        _field('Servidor IMAP (para leer)', _imapHost, hint: 'imap.gmail.com'),
        _field(
          'Puerto IMAP',
          _imapPort,
          hint: '993',
          keyboard: TextInputType.number,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Guardar')),
          ),
        ),
      ],
    );
  }
}
