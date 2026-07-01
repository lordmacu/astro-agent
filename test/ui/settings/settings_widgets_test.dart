import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/ui/settings/settings_widgets.dart';

void main() {
  testWidgets('SettingsSwitchTile toggles', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SettingsSwitchTile(
              label: 'Wake word',
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Wake word'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(value, true);
  });

  testWidgets('SettingsSection shows its title and children', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsSection(title: 'Voice', children: [Text('child')]),
        ),
      ),
    );
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('child'), findsOneWidget);
  });
}
