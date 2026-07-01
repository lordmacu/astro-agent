import 'package:flutter_test/flutter_test.dart';
import 'package:astro/platform/permissions.dart';

void main() {
  test('Permissions exposes the three request methods', () {
    const p = Permissions();
    expect(p.requestMicrophone, isA<Function>());
    expect(p.requestNotifications, isA<Function>());
    expect(p.requestLocation, isA<Function>());
  });
}
