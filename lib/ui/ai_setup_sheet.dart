import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/design_tokens.dart';
import '../core/config/settings_providers.dart';
import '../core/l10n/lang_provider.dart';
import '../core/l10n/strings.dart';
import 'settings/model_picker_tile.dart';

/// Shows the inline AI-setup modal (model + API key + provider hint). Resolves
/// to true once an LLM key has been saved, false on cancel/dismiss.
Future<bool> showAiSetupSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DesignTokens.bgBottomFallback,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AiSetupSheet(),
  );
  return saved ?? false;
}

class _AiSetupSheet extends ConsumerStatefulWidget {
  const _AiSetupSheet();

  @override
  ConsumerState<_AiSetupSheet> createState() => _AiSetupSheetState();
}

class _AiSetupSheetState extends ConsumerState<_AiSetupSheet> {
  final _keyController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    await ref.read(settingsProvider.notifier).setLlmApiKey(key);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Strings.aiSetupTitle(lang),
            style: const TextStyle(
              color: DesignTokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Strings.aiSetupBody(lang),
            style: const TextStyle(color: DesignTokens.dim),
          ),
          const SizedBox(height: 12),
          ModelPickerTile(
            currentModel: settings.llmModel,
            onChanged: notifier.setLlmModel,
            lang: lang,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keyController,
            obscureText: _obscure,
            autofocus: true,
            style: const TextStyle(color: DesignTokens.ink),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: Strings.aiKeyLabel(lang),
              labelStyle: const TextStyle(color: DesignTokens.dim),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                  color: DesignTokens.dim,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Strings.aiKeyHint(lang),
            style: const TextStyle(color: DesignTokens.dim, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _keyController.text.trim().isEmpty ? null : _save,
              child: Text(Strings.save(lang)),
            ),
          ),
        ],
      ),
    );
  }
}
