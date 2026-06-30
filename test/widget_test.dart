import 'package:chispa/app.dart';
import 'package:chispa/core/state/app_state.dart';
import 'package:chispa/core/state/app_state_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the resting mood on launch', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // No real sensors in tests; emit a single resting state.
        appStateProvider
            .overrideWith((ref) => Stream.value(const AppState())),
      ],
      child: const ChispaApp(),
    ));
    await tester.pump();

    // HUD renders with the speedometer unit and the resting event label.
    expect(find.text('km/h'), findsOneWidget);
    expect(find.text('EN REPOSO'), findsOneWidget);
  });
}
