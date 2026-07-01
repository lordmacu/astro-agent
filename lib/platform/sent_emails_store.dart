import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the email addresses Astro has sent to, most-recent-first (deduped,
/// capped), so it can reuse them later — injected into the brain's context so
/// "mándale otro correo a Ana" can reuse an address seen before.
class SentEmailsStore {
  const SentEmailsStore();

  static const _key = 'sent_email_recipients';
  static const _cap = 20;

  Future<List<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> add(String address) async {
    final a = address.trim();
    if (a.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.removeWhere((e) => e.toLowerCase() == a.toLowerCase());
    list.insert(0, a);
    if (list.length > _cap) list.removeRange(_cap, list.length);
    await prefs.setStringList(_key, list);
  }
}
