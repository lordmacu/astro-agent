import 'package:astro/platform/notifications_grouping.dart';
import 'package:astro/platform/notifications_reader.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationSummary _n(String app, int ms, {String? title, String? text}) =>
    NotificationSummary(
      app: app,
      title: title,
      text: text,
      time: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  test('groups by app, newest group and newest item first', () {
    final items = [_n('A', 3000), _n('B', 5000), _n('A', 1000)];
    final groups = groupNotificationsByApp(items);
    expect(groups.keys.toList(), ['B', 'A']); // B is newest (5000)
    expect(
      groups['A']!.map((e) => e.time!.millisecondsSinceEpoch).toList(),
      [3000, 1000], // newest first within the group
    );
  });

  test('unreadCount counts items strictly after "since"', () {
    final items = [_n('A', 1000), _n('A', 3000), _n('B', 5000)];
    final since = DateTime.fromMillisecondsSinceEpoch(2000);
    expect(unreadCount(items, since), 2); // 3000 and 5000
  });

  test('unreadCount ignores items without a timestamp', () {
    final items = [
      const NotificationSummary(app: 'A'), // no time
      _n('B', 5000),
    ];
    expect(unreadCount(items, DateTime.fromMillisecondsSinceEpoch(0)), 1);
  });
}
