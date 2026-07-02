import 'notifications_reader.dart';

/// Milliseconds for sorting; a missing timestamp sorts oldest.
int _ms(NotificationSummary n) => n.time?.millisecondsSinceEpoch ?? 0;

/// Group notifications by their app label. Groups are ordered by their most
/// recent notification first; within each group, items are newest-first.
Map<String, List<NotificationSummary>> groupNotificationsByApp(
  List<NotificationSummary> items,
) {
  final groups = <String, List<NotificationSummary>>{};
  for (final n in items) {
    (groups[n.app] ??= []).add(n);
  }
  for (final list in groups.values) {
    list.sort((a, b) => _ms(b).compareTo(_ms(a)));
  }
  final keys = groups.keys.toList()
    ..sort((a, b) => _ms(groups[b]!.first).compareTo(_ms(groups[a]!.first)));
  return {for (final k in keys) k: groups[k]!};
}

/// How many notifications arrived strictly after [since] (used for the badge).
int unreadCount(List<NotificationSummary> items, DateTime since) =>
    items.where((n) => n.time != null && n.time!.isAfter(since)).length;
