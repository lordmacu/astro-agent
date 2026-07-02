import 'package:flutter/material.dart';

import '../../core/config/design_tokens.dart';
import '../../core/config/llm_models.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/l10n/strings.dart';
import 'settings_widgets.dart';

/// OpenAI-compatible model presets offered in the dropdown; the driver can still
/// type any custom model via the "Personalizado…" option. MiniMax-M3 is the
/// default; the Kilo free model is offered right after it as a keyless option.
const List<String> kModelPresets = [
  'MiniMax-M3',
  kKiloFreeModel,
  'gpt-4o',
  'gpt-4o-mini',
  'gpt-4.1',
  'gpt-4.1-mini',
  'o3-mini',
  'deepseek-chat',
  'deepseek-reasoner',
];

/// Human-friendly label for a preset in the dropdown. The Kilo free model has an
/// ugly vendor id, so it shows as "Kilo · gratis/free"; everything else shows
/// its raw id.
String _presetLabel(String model, AppLang lang) {
  if (model == kKiloFreeModel) {
    return lang == AppLang.es ? 'Kilo · gratis' : 'Kilo · free';
  }
  return model;
}

/// Dropdown sentinel selected when the stored model is a custom (non-preset)
/// string, or when the user picks "Personalizado…".
const String kCustomModelSentinel = 'custom';

/// A model dropdown (presets + a custom option) that persists the chosen model
/// through [onChanged]. Reused by the settings screen and the inline AI-setup
/// sheet.
class ModelPickerTile extends StatefulWidget {
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
  State<ModelPickerTile> createState() => _ModelPickerTileState();
}

class _ModelPickerTileState extends State<ModelPickerTile> {
  /// True when the user chose "Personalizado…" OR the stored model is non-preset.
  late bool _customMode;

  @override
  void initState() {
    super.initState();
    _customMode = !kModelPresets.contains(widget.currentModel);
  }

  @override
  void didUpdateWidget(ModelPickerTile old) {
    super.didUpdateWidget(old);
    if (kModelPresets.contains(widget.currentModel)) {
      _customMode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownValue = _customMode
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
              for (final p in kModelPresets)
                DropdownMenuItem(
                  value: p,
                  child: Text(_presetLabel(p, widget.lang)),
                ),
              DropdownMenuItem(
                value: kCustomModelSentinel,
                child: Text(Strings.customModel(widget.lang)),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == kCustomModelSentinel) {
                setState(() => _customMode = true);
                return;
              }
              setState(() => _customMode = false);
              widget.onChanged(v);
            },
          ),
        ),
        if (_customMode)
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
