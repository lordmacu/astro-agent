import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_lang.dart';
import '../../core/l10n/lang_provider.dart';
import '../../core/l10n/strings.dart';

import '../../brain/astro_brain_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/design_tokens.dart';
import '../../core/config/llm_models.dart';
import '../../core/config/settings_providers.dart';
import '../../core/config/tool_catalog.dart';
import '../../core/config/tool_prefs.dart';
import '../../platform/permissions.dart';
import '../../platform/smtp_store.dart';
import '../../sensors/navigation/nav_service.dart';
// Neural-voice install UI is parked (see the commented block in the Voice
// section); re-add these imports when un-parking it.
// import '../../voice/neural_voice_installer.dart';
// import '../../voice/neural_voice_provider.dart';
import '../../voice/wake_word_provider.dart';
import 'model_picker_tile.dart';
import 'settings_widgets.dart';

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
    final lang = ref.watch(langProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.settingsTitle(lang)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          _languageSection(ref),
          const SizedBox(height: 24),
          SettingsSection(
            title: Strings.voiceSection(lang),
            children: [
              SettingsSliderTile(
                label: Strings.rateLabel(lang),
                value: settings.voiceRate,
                min: 0.3,
                max: 1.0,
                onChanged: notifier.setVoiceRate,
              ),
              SettingsSliderTile(
                label: Strings.pitchLabel(lang),
                value: settings.voicePitch,
                min: 0.5,
                max: 2.0,
                onChanged: notifier.setVoicePitch,
              ),
              // Voice-language selector (ES / EN) for the TTS engine.
              ListTile(
                title: Text(
                  Strings.language(lang),
                  style: const TextStyle(color: DesignTokens.ink),
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
              // Neural-voice UI (download + enable) is HIDDEN while the neural
              // engine is PARKED to keep the APK small (see tts_provider.dart /
              // pubspec). Un-comment this block — and un-park the engine — to
              // bring it back.
              /*
              Consumer(
                builder: (context, ref, _) {
                  final installState = ref.watch(voiceInstallStateProvider);
                  final installed = settings.neuralVoiceInstalled;
                  final subtitle = installState.maybeWhen(
                    data: (s) => switch (s) {
                      Installing(:final progress) =>
                        progress < 0
                            ? Strings.downloading(lang)
                            : Strings.downloadingPct(
                                (progress * 100).round(),
                                lang,
                              ),
                      InstallError(:final message) => Strings.errorPrefix(
                        message,
                        lang,
                      ),
                      Installed() => Strings.ready(lang),
                      NotInstalled() =>
                        installed
                            ? Strings.installed(lang)
                            : Strings.notDownloaded(lang),
                    },
                    orElse: () => installed
                        ? Strings.installed(lang)
                        : Strings.notDownloaded(lang),
                  );
                  return ListTile(
                    title: Text(
                      Strings.neuralVoice(lang),
                      style: const TextStyle(color: DesignTokens.ink),
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
                            child: Text(Strings.download(lang)),
                          ),
                  );
                },
              ),
              SettingsSwitchTile(
                label: Strings.useNeuralVoice(lang),
                subtitle: Strings.neuralVoiceHint(lang),
                value: settings.neuralVoiceEnabled,
                onChanged: settings.neuralVoiceInstalled
                    ? notifier.setNeuralVoiceEnabled
                    : (_) {},
              ),
              */
            ],
          ),
          const SizedBox(height: 24),
          SettingsSection(
            title: Strings.aiSection(lang),
            children: [
              ModelPickerTile(
                currentModel: settings.llmModel,
                lang: lang,
                onChanged: notifier.setLlmModel,
              ),
              // The Kilo free model is keyless (no LLM key, and no native web
              // search), so hide both API-key fields for it.
              if (!isFreeModel(settings.llmModel)) ...[
                SettingsTextTile(
                  label: Strings.llmApiKey(lang),
                  value: settings.llmApiKey,
                  obscure: true,
                  onSubmitted: notifier.setLlmApiKey,
                ),
                // Which search backend the key below belongs to.
                ListTile(
                  title: Text(
                    Strings.searchProviderLabel(lang),
                    style: const TextStyle(color: DesignTokens.ink),
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.searchProvider,
                    dropdownColor: const Color(0xFF1a2537),
                    style: const TextStyle(color: DesignTokens.ink),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'tavily', child: Text('Tavily')),
                      DropdownMenuItem(value: 'brave', child: Text('Brave')),
                    ],
                    onChanged: (v) {
                      if (v != null) notifier.setSearchProvider(v);
                    },
                  ),
                ),
                SettingsTextTile(
                  label: Strings.searchApiKey(lang),
                  value: settings.searchApiKey,
                  obscure: true,
                  onSubmitted: notifier.setSearchApiKey,
                ),
                // Dynamic link to where the selected provider's key is issued.
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.open_in_new,
                    color: DesignTokens.accent,
                    size: 18,
                  ),
                  title: Text(
                    Strings.getSearchKeyLink(settings.searchProvider, lang),
                    style: const TextStyle(
                      color: DesignTokens.accent,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => _openSearchKeyPage(settings.searchProvider),
                ),
              ],
              // Keyless search backend: used when no search API key is set,
              // before the DuckDuckGo fallback. Works with any model.
              SettingsTextTile(
                label: Strings.searxngUrl(lang),
                hint: 'https://searxng.example.com',
                value: settings.searxngUrl,
                onSubmitted: notifier.setSearxngUrl,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _EmailSection(lang: lang),
          const SizedBox(height: 24),
          SettingsSection(
            title: Strings.wakeSensorsSection(lang),
            children: [
              SettingsSwitchTile(
                label: Strings.wakeWordLabel(settings.wakeWord, lang),
                subtitle: Strings.wakeWordHint(lang),
                value: settings.wakeWordEnabled,
                onChanged: notifier.setWakeWordEnabled,
              ),
              SettingsTextTile(
                label: Strings.wakePhraseLabel(lang),
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
                label: Strings.sensitivity(lang),
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
              const _NavListenerTile(),
              SettingsSwitchTile(
                label: Strings.autoBrightness(lang),
                subtitle: Strings.autoBrightnessHint(lang),
                value: settings.autoBrightnessEnabled,
                onChanged: notifier.setAutoBrightnessEnabled,
              ),
              SettingsSwitchTile(
                label: Strings.haptics(lang),
                subtitle: Strings.hapticsHint(lang),
                value: settings.hapticsEnabled,
                onChanged: notifier.setHapticsEnabled,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _ToolsSection(),
          const SizedBox(height: 24),
          const _MemorySection(),
          const SizedBox(height: 24),
          SettingsSection(
            title: Strings.permissionsSection(lang),
            children: [
              ListTile(
                title: Text(
                  Strings.micPermission(lang),
                  style: const TextStyle(color: DesignTokens.ink),
                ),
                trailing: const Icon(Icons.mic, color: DesignTokens.dim),
                onTap: () => const Permissions().requestMicrophone(),
              ),
              ListTile(
                title: Text(
                  Strings.notificationsPermission(lang),
                  style: const TextStyle(color: DesignTokens.ink),
                ),
                trailing: const Icon(
                  Icons.notifications,
                  color: DesignTokens.dim,
                ),
                onTap: () => const Permissions().requestNotifications(),
              ),
              ListTile(
                title: Text(
                  Strings.locationPermission(lang),
                  style: const TextStyle(color: DesignTokens.ink),
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
            title: Strings.aboutSection(lang),
            children: [
              ListTile(
                title: const Text(
                  'Astro',
                  style: TextStyle(color: DesignTokens.ink),
                ),
                subtitle: Text(
                  Strings.aboutSubtitle(
                    _appVersion,
                    settings.neuralVoiceInstalled,
                    settings.llmModel,
                    lang,
                  ),
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

  /// Open the page where the selected search provider issues API keys.
  Future<void> _openSearchKeyPage(String provider) async {
    final url = provider == 'brave'
        ? 'https://api-dashboard.search.brave.com/app/keys'
        : 'https://app.tavily.com/home';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Tools section: one switch per brain tool the driver can turn on/off. A
/// disabled tool is dropped from the brain (the model can't call it). When an
/// enabled tool needs an OS permission it lacks, a tappable "grant" line shows.
class _ToolsSection extends ConsumerWidget {
  const _ToolsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: Strings.toolsSection(ref.watch(langProvider)),
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
    final lang = ref.watch(langProvider);
    final enabled = !ref.watch(toolPrefsProvider).contains(info.name);
    final needsGrant = enabled && info.permission != null && _granted == false;

    return ListTile(
      title: Text(
        Strings.toolLabel(info.name, lang),
        style: const TextStyle(color: DesignTokens.ink),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Strings.toolSubtitle(info.name, lang),
            style: const TextStyle(color: DesignTokens.dim),
          ),
          if (needsGrant)
            InkWell(
              onTap: _requestPermission,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  Strings.missingPermission(
                    Strings.permissionName(info.permissionKey ?? '', lang),
                    lang,
                  ),
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
    final lang = ref.watch(langProvider);
    return SettingsSection(
      title: Strings.memorySection(lang),
      children: [
        memoryAsync.when(
          loading: () => ListTile(
            title: Text(
              Strings.memorySection(lang),
              style: const TextStyle(color: DesignTokens.ink),
            ),
            trailing: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => ListTile(
            title: Text(
              Strings.memoryUnavailable(lang),
              style: const TextStyle(color: DesignTokens.dim),
            ),
          ),
          data: (memory) {
            if (memory == null) {
              return ListTile(
                title: Text(
                  Strings.memoryUnavailable(lang),
                  style: const TextStyle(color: DesignTokens.dim),
                ),
              );
            }
            // Reactive count: updates on its own when a conversation stores a
            // new memory (the extractor invalidates memoryCountProvider).
            final n = ref.watch(memoryCountProvider).valueOrNull ?? 0;
            return ListTile(
              title: Text(
                Strings.savedMemories(lang),
                style: const TextStyle(color: DesignTokens.ink),
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
                      title: Text(Strings.clearMemoryTitle(lang)),
                      content: Text(Strings.clearMemoryBody(lang)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(Strings.cancel(lang)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(Strings.delete(lang)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await memory.clearAll();
                    ref.invalidate(memoryCountProvider); // refresh the counter
                  }
                },
                child: Text(Strings.delete(lang)),
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
  const _EmailSection({required this.lang});

  final AppLang lang;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.cantOpenLink(widget.lang))),
      );
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
      ).showSnackBar(SnackBar(content: Text(Strings.emailSaved(widget.lang))));
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
    final lang = widget.lang;
    if (!_loaded) {
      return SettingsSection(
        title: Strings.emailSection(lang),
        children: [
          ListTile(
            title: Text(
              Strings.loading(lang),
              style: const TextStyle(color: DesignTokens.dim),
            ),
          ),
        ],
      );
    }
    return SettingsSection(
      title: Strings.emailSection(lang),
      children: [
        _field(Strings.smtpServer(lang), _host, hint: 'smtp.gmail.com'),
        _field(
          Strings.port(lang),
          _port,
          hint: '587',
          keyboard: TextInputType.number,
        ),
        _field(
          Strings.emailUser(lang),
          _user,
          hint: 'tucorreo@gmail.com',
          keyboard: TextInputType.emailAddress,
        ),
        _field(Strings.passwordOrAppPassword(lang), _pass, obscure: true),
        ListTile(
          dense: true,
          leading: const Icon(
            Icons.open_in_new,
            color: DesignTokens.accent,
            size: 18,
          ),
          title: Text(
            Strings.createGmailAppPassword(lang),
            style: const TextStyle(color: DesignTokens.accent, fontSize: 13),
          ),
          subtitle: Text(
            Strings.appPasswordHint(lang),
            style: const TextStyle(color: DesignTokens.dim, fontSize: 11),
          ),
          onTap: _openAppPasswordHelp,
        ),
        _field(Strings.senderName(lang), _from, hint: 'Astro'),
        _field(Strings.imapServer(lang), _imapHost, hint: 'imap.gmail.com'),
        _field(
          Strings.imapPort(lang),
          _imapPort,
          hint: '993',
          keyboard: TextInputType.number,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(Strings.save(lang)),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Maps-nav toggle. A stateful widget (not an inline `Consumer`) so it can
/// re-check the notification-listener grant when the app resumes. That access is
/// granted in system settings, so the user leaves and returns; without the
/// re-check the "grant access" hint stays stuck even after they've granted it.
class _NavListenerTile extends ConsumerStatefulWidget {
  const _NavListenerTile();

  @override
  ConsumerState<_NavListenerTile> createState() => _NavListenerTileState();
}

class _NavListenerTileState extends ConsumerState<_NavListenerTile>
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(navPermissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final lang = ref.watch(langProvider);
    final hasPermission = ref.watch(navPermissionProvider).valueOrNull ?? true;
    final subtitle = settings.navListenerEnabled && !hasPermission
        ? Strings.navGrantHint(lang)
        : Strings.navOnHint(lang);
    return SettingsSwitchTile(
      label: Strings.navLabel(lang),
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
  }
}
