/// Fuzzy contact matching. Speech recognition often hears a name slightly off
/// ("esposita" for "esposa", "mama" for "Mamá ❤️"), so we pick the closest
/// contact by similarity rather than an exact substring. Pure and testable.
library;

/// A contact reduced to what matching needs.
class ContactCandidate {
  const ContactCandidate({required this.name, required this.number});
  final String name;
  final String number;
}

/// A contact reduced to a name + one email address, for fuzzy email lookup.
class EmailCandidate {
  const EmailCandidate({required this.name, required this.email});
  final String name;
  final String email;
}

/// The part of an email address before the "@", or '' if [s] isn't an address.
String emailLocalPart(String s) {
  final at = s.indexOf('@');
  return at > 0 ? s.substring(0, at) : '';
}

/// The saved contacts whose name (or email local-part) best matches [query],
/// best first, deduped by address, capped at [max]. The recognizer often mangles
/// a spoken email, so we match what was heard against the contact's NAME and the
/// part of its address before the "@". Empty when nothing is close.
List<EmailCandidate> bestEmailMatches(
  String query,
  List<EmailCandidate> contacts, {
  double threshold = 0.62,
  int max = 4,
}) {
  // If the driver spelled out an address, match on its local part — a raw email
  // would otherwise normalize to junk ("juan@gmail.com" -> "juangmailcom").
  final local = emailLocalPart(query);
  final q = normalizeName(local.isNotEmpty ? local : query);
  if (q.isEmpty) return const [];

  final scored = <({EmailCandidate c, double score})>[];
  for (final c in contacts) {
    if (c.email.isEmpty) continue;

    var score = 0.0;
    final full = normalizeName(c.name);
    if (full.isNotEmpty) {
      score = nameScore(q, full);
      for (final token in full.split(' ')) {
        if (token.isEmpty) continue;
        final s = nameScore(q, token);
        if (s > score) score = s;
      }
    }
    // Also score against the address's local part, so a heard/guessed email
    // still finds the contact even when the name doesn't match.
    final addr = normalizeName(emailLocalPart(c.email));
    if (addr.isNotEmpty) {
      final s = nameScore(q, addr);
      if (s > score) score = s;
    }
    if (score >= threshold) scored.add((c: c, score: score));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  final seen = <String>{};
  final out = <EmailCandidate>[];
  for (final s in scored) {
    if (seen.add(s.c.email.toLowerCase())) out.add(s.c);
    if (out.length >= max) break;
  }
  return out;
}

/// Return the phone number of the single closest contact to [query], or null if
/// nothing is similar enough.
String? matchContactNumber(
  String query,
  List<ContactCandidate> contacts, {
  double threshold = 0.62,
}) {
  final best = bestContactMatches(
    query,
    contacts,
    threshold: threshold,
    max: 1,
  );
  return best.isEmpty ? null : best.first.number;
}

/// Return the contacts most similar to [query], best first, each scoring at or
/// above [threshold], capped at [max] and deduped by number. Empty when nothing
/// is close. Use the length to decide the UX: 1 → confirm, 2+ → let the driver
/// pick.
List<ContactCandidate> bestContactMatches(
  String query,
  List<ContactCandidate> contacts, {
  double threshold = 0.62,
  int max = 4,
}) {
  final q = normalizeName(query);
  if (q.isEmpty) return const [];

  final scored = <({ContactCandidate c, double score})>[];
  for (final c in contacts) {
    if (c.number.isEmpty) continue;
    final full = normalizeName(c.name);
    if (full.isEmpty) continue;

    var score = nameScore(q, full);
    for (final token in full.split(' ')) {
      if (token.isEmpty) continue;
      final s = nameScore(q, token);
      if (s > score) score = s;
    }
    if (score >= threshold) scored.add((c: c, score: score));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  final seen = <String>{};
  final out = <ContactCandidate>[];
  for (final s in scored) {
    if (seen.add(s.c.number)) out.add(s.c);
    if (out.length >= max) break;
  }
  return out;
}

/// Lowercase, strip accents and anything that isn't a letter/digit/space
/// (emoji, punctuation), and collapse whitespace.
String normalizeName(String s) {
  const accented = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const plain = 'aaaaaeeeeiiiiooooouuuunc';
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = accented.indexOf(ch);
    if (i >= 0) {
      out.write(plain[i]);
    } else if (RegExp(r'[a-z0-9 ]').hasMatch(ch)) {
      out.write(ch);
    }
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Similarity in 0..1 between two normalized strings: exact, prefix, substring,
/// then the better of a Levenshtein ratio and a shared-prefix score. The prefix
/// score rescues names that differ mainly at the end — gender/ending swaps like
/// "esposito" vs "esposa" — which pure edit distance scores too low.
double nameScore(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  if (b.startsWith(a) || a.startsWith(b)) return 0.9;
  if (b.contains(a) || a.contains(b)) return 0.82;

  final maxLen = a.length > b.length ? a.length : b.length;
  final lev = 1 - levenshtein(a, b) / maxLen;

  final minLen = a.length < b.length ? a.length : b.length;
  final prefix = _commonPrefix(a, b);
  final prefixRatio = minLen == 0 ? 0.0 : prefix / minLen;
  // Only reward a *substantial* shared prefix, so unrelated names stay low.
  final prefixScore = prefixRatio >= 0.7 ? 0.55 + 0.4 * prefixRatio : 0.0;

  return lev > prefixScore ? lev : prefixScore;
}

int _commonPrefix(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  var i = 0;
  while (i < n && a[i] == b[i]) {
    i++;
  }
  return i;
}

/// Levenshtein edit distance (two-row DP).
int levenshtein(String a, String b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (i) => i);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final del = prev[j] + 1;
      final ins = curr[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}
