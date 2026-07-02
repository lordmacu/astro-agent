import 'package:flutter/material.dart';

import '../core/config/design_tokens.dart';
import '../core/config/tool_catalog.dart';
import '../core/l10n/app_lang.dart';
import '../core/l10n/strings.dart';

/// The ordered list of localized example commands shown in the palette:
/// get_context first, then one per toggleable tool in [kToolCatalog]. Tools
/// without a defined example are skipped.
List<String> astroCommands(AppLang lang) {
  final out = <String>[];
  void add(String toolName) {
    final c = Strings.commandExample(toolName, lang);
    if (c.isNotEmpty) out.add(c);
  }

  add('get_context');
  for (final info in kToolCatalog) {
    add(info.name);
  }
  return out;
}

/// A popup card listing [commands] as tappable buttons. [onCommand] fires with
/// the command text; [onClose] dismisses. Presentation only — the caller wires
/// tapping to the brain.
class CommandPalette extends StatelessWidget {
  const CommandPalette({
    super.key,
    required this.commands,
    required this.onCommand,
    required this.onClose,
    required this.lang,
  });

  final List<String> commands;
  final void Function(String command) onCommand;
  final VoidCallback onClose;
  final AppLang lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.bgBottomFallback,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Strings.commandsTitle(lang),
                  style: const TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: DesignTokens.dim),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final cmd in commands)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ElevatedButton(
                        onPressed: () => onCommand(cmd),
                        child: Text(cmd),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
