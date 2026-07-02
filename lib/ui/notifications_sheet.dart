import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brain/astro_brain_provider.dart';
import '../core/config/design_tokens.dart';
import '../core/l10n/app_lang.dart';
import '../core/l10n/lang_provider.dart';
import '../core/l10n/strings.dart';
import '../platform/notifications_grouping.dart';
import '../platform/notifications_reader.dart';
import '../platform/permissions.dart';

/// Show the notifications panel. [onSpeak] receives each AI summary so the
/// caller can voice it. [reader] is injectable for tests.
Future<void> showNotificationsSheet(
  BuildContext context, {
  required void Function(String summary) onSpeak,
  NotificationsReader reader = const NotificationsReader(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DesignTokens.bgBottomFallback,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _NotificationsSheet(onSpeak: onSpeak, reader: reader),
  );
}

class _NotificationsSheet extends ConsumerStatefulWidget {
  const _NotificationsSheet({required this.onSpeak, required this.reader});
  final void Function(String summary) onSpeak;
  final NotificationsReader reader;
  @override
  ConsumerState<_NotificationsSheet> createState() =>
      _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<_NotificationsSheet> {
  Map<String, List<NotificationSummary>>? _groups; // null = loading
  final _summaries = <String, String>{};
  final _loading = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.reader.recent(count: 40);
    if (!mounted) return;
    setState(() => _groups = groupNotificationsByApp(items));
  }

  Future<void> _summarize(
    String key,
    String app,
    List<NotificationSummary> items,
  ) async {
    final lang = ref.read(langProvider);
    setState(() => _loading.add(key));
    try {
      final summary = await ref
          .read(notificationSummarizerProvider)
          .summarize(items, lang: lang, app: app);
      if (!mounted) return;
      setState(() => _summaries[key] = summary);
      widget.onSpeak(summary);
    } on Object {
      if (!mounted) return;
      setState(() => _summaries[key] = Strings.notifSummaryError(lang));
    } finally {
      if (mounted) setState(() => _loading.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final groups = _groups;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Strings.notificationsTitle(lang),
            style: const TextStyle(
              color: DesignTokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (groups == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (groups.isEmpty)
            _EmptyState(lang: lang, onGranted: _load)
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in groups.entries)
                    _AppGroup(
                      app: entry.key,
                      items: entry.value,
                      lang: lang,
                      summaries: _summaries,
                      loading: _loading,
                      onSummarizeGroup: () =>
                          _summarize('g:${entry.key}', entry.key, entry.value),
                      onSummarizeItem: (i) => _summarize(
                        'i:${entry.key}#$i',
                        entry.key,
                        [entry.value[i]],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AppGroup extends StatelessWidget {
  const _AppGroup({
    required this.app,
    required this.items,
    required this.lang,
    required this.summaries,
    required this.loading,
    required this.onSummarizeGroup,
    required this.onSummarizeItem,
  });

  final String app;
  final List<NotificationSummary> items;
  final AppLang lang;
  final Map<String, String> summaries;
  final Set<String> loading;
  final VoidCallback onSummarizeGroup;
  final void Function(int index) onSummarizeItem;

  @override
  Widget build(BuildContext context) {
    final groupKey = 'g:$app';
    final hasSummary = summaries[groupKey] != null;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // Re-key so a fresh group summary forces the tile open: `initiallyExpanded`
        // only takes effect when ExpansionTile's own state is (re)created.
        key: ValueKey('$app-$hasSummary'),
        initiallyExpanded: hasSummary,
        collapsedIconColor: DesignTokens.dim,
        iconColor: DesignTokens.accent,
        title: Text(
          '$app (${items.length})',
          style: const TextStyle(color: DesignTokens.ink),
        ),
        trailing: loading.contains(groupKey)
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onSummarizeGroup,
                child: Text(Strings.summarize(lang)),
              ),
        children: [
          if (summaries[groupKey] != null)
            _SummaryBox(text: summaries[groupKey]!),
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              title: Text(
                items[i].title ?? items[i].app,
                style: const TextStyle(color: DesignTokens.ink, fontSize: 14),
              ),
              subtitle: Text(
                items[i].text ?? '',
                style: const TextStyle(color: DesignTokens.dim, fontSize: 12),
              ),
              trailing: loading.contains('i:$app#$i')
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      color: DesignTokens.dim,
                      size: 18,
                    ),
              onTap: () => onSummarizeItem(i),
            ),
            if (summaries['i:$app#$i'] != null)
              _SummaryBox(text: summaries['i:$app#$i']!),
          ],
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: DesignTokens.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(color: DesignTokens.ink, fontSize: 13),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang, required this.onGranted});
  final AppLang lang;
  final Future<void> Function() onGranted;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Text(
          Strings.noNotifications(lang),
          style: const TextStyle(color: DesignTokens.dim),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await const Permissions().requestNotifications();
            await onGranted();
          },
          child: Text(Strings.grantNotifications(lang)),
        ),
      ],
    ),
  );
}
