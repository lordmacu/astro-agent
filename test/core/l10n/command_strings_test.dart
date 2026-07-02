import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/config/tool_catalog.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/strings.dart';
import 'package:astro/ui/command_palette.dart';

void main() {
  for (final l in AppLang.values) {
    test('commandsTitle non-empty for $l', () {
      expect(Strings.commandsTitle(l), isNotEmpty);
    });

    test('every catalog tool + get_context has a command example for $l', () {
      expect(Strings.commandExample('get_context', l), isNotEmpty);
      for (final info in kToolCatalog) {
        expect(
          Strings.commandExample(info.name, l),
          isNotEmpty,
          reason: 'missing command example for ${info.name} ($l)',
        );
      }
    });

    test('astroCommands is non-empty with no blank entries for $l', () {
      final cmds = astroCommands(l);
      expect(cmds, isNotEmpty);
      expect(cmds.any((c) => c.trim().isEmpty), isFalse);
      // get_context example leads the list.
      expect(cmds.first, Strings.commandExample('get_context', l));
    });
  }

  test('an unknown tool name yields an empty example', () {
    expect(Strings.commandExample('nope_not_a_tool', AppLang.es), isEmpty);
  });
}
