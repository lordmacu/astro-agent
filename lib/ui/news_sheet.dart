import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brain/tools/news/google_news_provider.dart';
import '../core/config/design_tokens.dart';
import '../core/l10n/lang_provider.dart';
import '../core/l10n/strings.dart';

/// Open a news article in the default browser.
Future<bool> _launchExternal(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Show the clickable news panel. Pass [headlines] to render a list the brain
/// already fetched (voice path); omit it to fetch the top headlines (icon path).
/// [launch] is injectable for tests.
Future<void> showNewsSheet(
  BuildContext context, {
  List<NewsHeadline>? headlines,
  Future<bool> Function(Uri) launch = _launchExternal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DesignTokens.bgBottomFallback,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _NewsSheet(headlines: headlines, launch: launch),
  );
}

class _NewsSheet extends ConsumerStatefulWidget {
  const _NewsSheet({required this.headlines, required this.launch});
  final List<NewsHeadline>? headlines;
  final Future<bool> Function(Uri) launch;
  @override
  ConsumerState<_NewsSheet> createState() => _NewsSheetState();
}

class _NewsSheetState extends ConsumerState<_NewsSheet> {
  List<NewsHeadline>? _items; // null = loading
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final given = widget.headlines;
    if (given != null) {
      _items = given;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final items = await ref
          .read(googleNewsProvider)
          .headlines(lang: ref.read(langProvider));
      if (!mounted) return;
      setState(() => _items = items);
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await widget.launch(uri);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final items = _items;
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
            Strings.newsTitle(lang),
            style: const TextStyle(
              color: DesignTokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_failed || (items != null && items.isEmpty))
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                Strings.newsUnavailable(lang),
                style: const TextStyle(color: DesignTokens.dim),
              ),
            )
          else if (items == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final h = items[i];
                  return ListTile(
                    title: Text(
                      h.title,
                      style: const TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: h.source.isEmpty
                        ? null
                        : Text(
                            h.source,
                            style: const TextStyle(
                              color: DesignTokens.dim,
                              fontSize: 12,
                            ),
                          ),
                    trailing: const Icon(
                      Icons.open_in_new,
                      color: DesignTokens.dim,
                      size: 18,
                    ),
                    onTap: () => _open(h.url),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
