import 'package:astro/core/state/app_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppMode.isCar', () {
    expect(AppMode.car.isCar, isTrue);
    expect(AppMode.normal.isCar, isFalse);
  });

  group('AppModeStore', () {
    test(
      'load returns null when nothing is stored (→ default normal)',
      () async {
        SharedPreferences.setMockInitialValues({});
        expect(await const AppModeStore().load(), isNull);
      },
    );

    test('save then load round-trips car', () async {
      SharedPreferences.setMockInitialValues({});
      const store = AppModeStore();
      await store.save(AppMode.car);
      expect(await store.load(), AppMode.car);
    });

    test('save then load round-trips normal', () async {
      SharedPreferences.setMockInitialValues({});
      const store = AppModeStore();
      await store.save(AppMode.normal);
      expect(await store.load(), AppMode.normal);
    });

    test('an unrecognised stored value loads as null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_mode', 'bogus');
      expect(await const AppModeStore().load(), isNull);
    });
  });
}
