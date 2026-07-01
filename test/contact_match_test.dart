import 'package:astro/platform/contact_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final contacts = [
    const ContactCandidate(name: 'Mi Esposa ❤️', number: '+573001112233'),
    const ContactCandidate(name: 'Mamá', number: '+573004445566'),
    const ContactCandidate(name: 'Juan Carlos Pérez', number: '+573007778899'),
    const ContactCandidate(name: 'Trabajo', number: '+573009990000'),
  ];

  String? match(String q) => matchContactNumber(q, contacts);

  group('normalizeName', () {
    test('strips accents, emoji, and case', () {
      expect(normalizeName('Mamá ❤️'), 'mama');
      expect(normalizeName('Mi Esposa ❤️'), 'mi esposa');
      expect(normalizeName('Pérez'), 'perez');
    });
  });

  group('matchContactNumber', () {
    test('mishearing "esposita" still finds the wife', () {
      expect(match('esposita'), '+573001112233');
    });

    test('gender/ending swap "esposito" still finds the wife', () {
      expect(match('esposito'), '+573001112233');
      expect(match('esposa'), '+573001112233');
    });

    test('exact token match wins', () {
      expect(match('mamá'), '+573004445566');
      expect(match('juan'), '+573007778899');
    });

    test('partial / prefix match works', () {
      expect(match('juan carlos'), '+573007778899');
      expect(match('perez'), '+573007778899');
    });

    test('a clearly-unknown name returns null', () {
      expect(match('federico'), isNull);
      expect(match(''), isNull);
    });

    test('a raw contact with no number is skipped', () {
      final one = [const ContactCandidate(name: 'Ana', number: '')];
      expect(matchContactNumber('ana', one), isNull);
    });
  });

  group('bestContactMatches', () {
    final many = [
      const ContactCandidate(name: 'Juan Carlos', number: '1'),
      const ContactCandidate(name: 'Juan Pablo', number: '2'),
      const ContactCandidate(name: 'Mamá', number: '3'),
    ];

    test('a single clear match returns one', () {
      final r = bestContactMatches('mama', many);
      expect(r, hasLength(1));
      expect(r.first.number, '3');
    });

    test('several close matches all come back, best first', () {
      final r = bestContactMatches('juan', many);
      expect(r.length, 2);
      expect(r.map((c) => c.number), containsAll(['1', '2']));
    });

    test('nothing close returns empty', () {
      expect(bestContactMatches('zzz', many), isEmpty);
    });

    test('dedupes by number and caps at max', () {
      final dup = [
        const ContactCandidate(name: 'Ana', number: '9'),
        const ContactCandidate(name: 'Ana María', number: '9'),
        const ContactCandidate(name: 'Ana Lucía', number: '8'),
      ];
      final r = bestContactMatches('ana', dup, max: 2);
      expect(r.length, lessThanOrEqualTo(2));
      expect(r.map((c) => c.number).toSet().length, r.length); // no dup numbers
    });
  });

  group('emailLocalPart', () {
    test('returns the part before @, or empty for a non-address', () {
      expect(emailLocalPart('juan.perez@gmail.com'), 'juan.perez');
      expect(emailLocalPart('juan'), '');
      expect(emailLocalPart(''), '');
    });
  });

  group('bestEmailMatches', () {
    final emails = [
      const EmailCandidate(name: 'Juan Carlos Pérez', email: 'juancp@gmail.com'),
      const EmailCandidate(name: 'Mi Esposa ❤️', email: 'ana@work.co'),
      const EmailCandidate(name: 'Trabajo', email: 'info@empresa.com'),
    ];

    test('resolves a spoken name to the contact email', () {
      final r = bestEmailMatches('juan', emails);
      expect(r, hasLength(1));
      expect(r.first.email, 'juancp@gmail.com');
    });

    test('a mangled/guessed address still finds the contact by local part', () {
      final r = bestEmailMatches('juancp@hotmail.com', emails);
      expect(r.first.email, 'juancp@gmail.com');
    });

    test('gender/ending swap "esposito" finds the wife', () {
      final r = bestEmailMatches('esposito', emails);
      expect(r.first.email, 'ana@work.co');
    });

    test('nothing close returns empty', () {
      expect(bestEmailMatches('federico', emails), isEmpty);
      expect(bestEmailMatches('', emails), isEmpty);
    });

    test('dedupes by address and caps at max', () {
      final dup = [
        const EmailCandidate(name: 'Ana', email: 'ana@x.com'),
        const EmailCandidate(name: 'Ana María', email: 'ana@x.com'),
        const EmailCandidate(name: 'Ana Lucía', email: 'anal@x.com'),
      ];
      final r = bestEmailMatches('ana', dup, max: 2);
      expect(r.length, lessThanOrEqualTo(2));
      expect(r.map((c) => c.email).toSet().length, r.length);
    });

    test('a candidate with no address is skipped', () {
      final one = [const EmailCandidate(name: 'Ana', email: '')];
      expect(bestEmailMatches('ana', one), isEmpty);
    });
  });

  group('nameScore', () {
    test('exact is 1, close is high, far is low', () {
      expect(nameScore('esposa', 'esposa'), 1);
      expect(nameScore('esposita', 'esposa'), greaterThan(0.7));
      expect(nameScore('juan', 'trabajo'), lessThan(0.4));
    });
  });
}
