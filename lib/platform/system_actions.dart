import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contact_match.dart';

/// Thin platform glue for the action tools (navigate, timer, device flashlight,
/// phone). Each function is best-effort and returns false instead of throwing,
/// so a tool can report a friendly failure. The tool classes inject these, so
/// they stay unit-testable without any of this.
class SystemActions {
  const SystemActions();

  /// Open turn-by-turn navigation to [destination] in the maps app.
  Future<bool> navigate(String destination) async {
    final nav = Uri.parse(
      'google.navigation:q=${Uri.encodeComponent(destination)}',
    );
    if (await _tryLaunch(nav)) return true;
    // Fallback: Maps directions over https (works even without the app).
    return _tryLaunch(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
        '${Uri.encodeComponent(destination)}',
      ),
    );
  }

  /// Open the map searching for [query] near the current location (gas
  /// stations, ATMs, restaurants…). `geo:0,0?q=` centres on the user.
  Future<bool> nearby(String query) async {
    final geo = Uri.parse('geo:0,0?q=${Uri.encodeComponent(query)}');
    if (await _tryLaunch(geo)) return true;
    return _tryLaunch(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query='
        '${Uri.encodeComponent(query)}',
      ),
    );
  }

  /// Set a countdown timer via the system clock app.
  Future<bool> setTimer(int seconds, String? label) =>
      _fireIntent('android.intent.action.SET_TIMER', {
        'android.intent.extra.alarm.LENGTH': seconds,
        'android.intent.extra.alarm.SKIP_UI': true,
        if (label != null && label.isNotEmpty)
          'android.intent.extra.alarm.MESSAGE': label,
      });

  /// Set an alarm via the system clock app.
  Future<bool> setAlarm(int hour, int minute, String? label) =>
      _fireIntent('android.intent.action.SET_ALARM', {
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        'android.intent.extra.alarm.SKIP_UI': true,
        if (label != null && label.isNotEmpty)
          'android.intent.extra.alarm.MESSAGE': label,
      });

  Future<void> setTorch(bool on) async {
    if (on) {
      await TorchLight.enableTorch();
    } else {
      await TorchLight.disableTorch();
    }
  }

  /// Place a call. Asks for CALL_PHONE so Astro can dial directly; if the
  /// permission is denied (or the direct call fails), opens the dialer prefilled
  /// so the driver can tap once.
  Future<bool> call(String number) async {
    if (await Permission.phone.request().isGranted) {
      final direct = await _fireIntent(
        'android.intent.action.CALL',
        const {},
        data: 'tel:$number',
      );
      if (direct) return true;
    }
    return _tryLaunch(Uri.parse('tel:$number'));
  }

  /// Open the default mail app's composer, pre-filled, via a `mailto:` URI.
  /// Best-effort: the user reviews and sends manually.
  Future<bool> composeEmail({
    required String to,
    required String subject,
    required String body,
  }) {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: _mailtoQuery(subject: subject, body: body),
    );
    return _tryLaunch(uri);
  }

  /// Open the phone's default email app (no compose), via ACTION_MAIN +
  /// CATEGORY_APP_EMAIL. Best-effort.
  Future<bool> openEmailApp() => _fireIntent(
    'android.intent.action.MAIN',
    const {},
    category: 'android.intent.category.APP_EMAIL',
  );

  /// Open a message prefilled with [text] (WhatsApp by default, else SMS).
  Future<bool> message(String number, String text, bool viaWhatsApp) {
    final encoded = Uri.encodeComponent(text);
    final uri = viaWhatsApp
        ? Uri.parse('https://wa.me/${_digits(number)}?text=$encoded')
        : Uri.parse('sms:$number?body=$encoded');
    return _tryLaunch(uri);
  }

  /// Look up a saved contact's phone number by name, fuzzily — the recognizer
  /// often hears a name slightly off, so we pick the closest contact.
  Future<String?> resolveContact(String name) async {
    final matches = await matchingContacts(name, max: 1);
    return matches.isEmpty ? null : matches.first.number;
  }

  /// The contacts whose name best matches [name] (fuzzy), best first. Empty if
  /// permission is denied or nothing is close. Lets the caller decide the UX:
  /// one match → confirm, several → let the driver pick.
  Future<List<ContactCandidate>> matchingContacts(
    String name, {
    int max = 4,
  }) async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      return const [];
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final candidates = [
      for (final c in contacts)
        if (c.phones.isNotEmpty)
          ContactCandidate(name: c.displayName, number: c.phones.first.number),
    ];
    return bestContactMatches(name, candidates, max: max);
  }

  /// The saved contacts whose name (or address) best matches [query], each with
  /// one email, best first. A contact with several emails yields one candidate
  /// per address. Empty if permission is denied or nothing is close. Lets the
  /// caller prefill the recipient when the recognizer mangled a spoken email.
  Future<List<EmailCandidate>> matchingContactEmails(
    String query, {
    int max = 4,
  }) async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      return const [];
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final candidates = [
      for (final c in contacts)
        for (final e in c.emails)
          if (e.address.trim().isNotEmpty)
            EmailCandidate(name: c.displayName, email: e.address.trim()),
    ];
    return bestEmailMatches(query, candidates, max: max);
  }

  Future<bool> _fireIntent(
    String action,
    Map<String, dynamic> arguments, {
    String? data,
    String? category,
  }) async {
    try {
      await AndroidIntent(
        action: action,
        arguments: arguments,
        data: data,
        category: category,
      ).launch();
      debugPrint('[intent] $action OK  args=$arguments');
      return true;
    } catch (e) {
      debugPrint('[intent] $action FAILED: $e  args=$arguments');
      return false;
    }
  }

  Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  String _digits(String number) => number.replaceAll(RegExp(r'[^0-9]'), '');

  /// Build a `mailto:` query string with URL-encoded subject and body, omitting
  /// empty parts.
  String _mailtoQuery({required String subject, required String body}) {
    final parts = <String>[
      if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
      if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
    ];
    return parts.join('&');
  }
}
