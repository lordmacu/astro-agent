import 'package:astro/core/util/calibration_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalibrationStore', () {
    test('returns null when nothing has been saved', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await CalibrationStore().load(), isNull);
    });

    test('round-trips the accumulator through shared preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final store = CalibrationStore();
      await store.save([1.5, -2.0, 3.25]);

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded![0], closeTo(1.5, 1e-9));
      expect(loaded[1], closeTo(-2.0, 1e-9));
      expect(loaded[2], closeTo(3.25, 1e-9));
    });

    test('ignores a corrupt stored value', () async {
      SharedPreferences.setMockInitialValues({
        'forward_axis_accumulator': ['not', 'a', 'number'],
      });
      expect(await CalibrationStore().load(), isNull);
    });
  });
}
