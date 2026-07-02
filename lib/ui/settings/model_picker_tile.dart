import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/llm/kilo_models.dart';
import '../../core/config/design_tokens.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/l10n/strings.dart';
import 'settings_widgets.dart';

/// Paid model presets always shown in the dropdown. Free Kilo models are
/// fetched live (see [kiloFreeModelsProvider]) and listed above these; the
/// driver can still type any custom model via the "Personalizado…" option.
const List<String> kPaidModelPresets = [
  'MiniMax-M3',
  'gpt-4o',
  'gpt-4o-mini',
  'gpt-4.1',
  'gpt-4.1-mini',
  'o3-mini',
  'deepseek-chat',
  'deepseek-reasoner',
];

/// Dropdown sentinel selected when the stored model is a custom (non-preset)
/// string, or when the user picks "Personalizado…".
const String kCustomModelSentinel = 'custom';

/// A model dropdown (live free models + paid presets + a custom option) that
/// persists the chosen model through [onChanged]. Reused by the settings screen
/// and the inline AI-setup sheet.
class ModelPickerTile extends ConsumerStatefulWidget {
  const ModelPickerTile({
    super.key,
    required this.currentModel,
    required this.onChanged,
    required this.lang,
  });

  final String currentModel;
  final ValueChanged<String> onChanged;
  final AppLang lang;

  @override
  ConsumerState<ModelPickerTile> createState() => _ModelPickerTileState();
}

class _ModelPickerTileState extends ConsumerState<ModelPickerTile> {
  /// True only when the user explicitly picked "Personalizado…". A non-preset
  /// stored model also shows the custom field (computed in [build]).
  bool _userChoseCustom = false;

  String _freeWord(AppLang lang) => lang == AppLang.es ? 'gratis' : 'free';

  @override
  Widget build(BuildContext context) {
    // Live free models (fetched from Kilo), or the seed list while loading / on
    // error so the default free model is always a valid dropdown entry.
    final free =
        ref.watch(kiloFreeModelsProvider).asData?.value ?? kSeedFreeModels;
    final freeIds = {for (final m in free) m.id};

    final isPreset =
        kPaidModelPresets.contains(widget.currentModel) ||
        freeIds.contains(widget.currentModel);
    final customMode = _userChoseCustom || !isPreset;
    final dropdownValue = customMode
        ? kCustomModelSentinel
        : widget.currentModel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(
            Strings.modelLabel(widget.lang),
            style: const TextStyle(color: DesignTokens.ink),
          ),
          trailing: DropdownButton<String>(
            value: dropdownValue,
            dropdownColor: const Color(0xFF1a2537),
            style: const TextStyle(color: DesignTokens.ink, fontSize: 14),
            underline: const SizedBox.shrink(),
            items: [
              // Free (live from Kilo) — labeled "· gratis/free".
              for (final m in free)
                DropdownMenuItem(
                  value: m.id,
                  child: Text('${m.name} · ${_freeWord(widget.lang)}'),
                ),
              // Paid presets.
              for (final p in kPaidModelPresets)
                DropdownMenuItem(value: p, child: Text(p)),
              DropdownMenuItem(
                value: kCustomModelSentinel,
                child: Text(Strings.customModel(widget.lang)),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == kCustomModelSentinel) {
                setState(() => _userChoseCustom = true);
                return;
              }
              setState(() => _userChoseCustom = false);
              widget.onChanged(v);
            },
          ),
        ),
        if (customMode)
          SettingsTextTile(
            label: Strings.customModelLabel(widget.lang),
            value: widget.currentModel,
            hint: 'MiniMax-M3',
            onSubmitted: widget.onChanged,
          ),
      ],
    );
  }
}
