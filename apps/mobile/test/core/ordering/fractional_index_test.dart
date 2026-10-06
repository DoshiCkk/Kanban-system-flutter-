import 'dart:math';

import 'package:flowboard/core/ordering/fractional_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateKeyBetween', () {
    // Reference values from rocicorp/fractional-indexing's test suite.
    final cases = <(String?, String?, String)>[
      (null, null, 'a0'),
      (null, 'a0', 'Zz'),
      (null, 'Zz', 'Zy'),
      ('a0', null, 'a1'),
      ('a1', null, 'a2'),
      ('a0', 'a1', 'a0V'),
      ('a1', 'a2', 'a1V'),
      ('a0V', 'a1', 'a0l'),
      ('Zz', 'a0', 'ZzV'),
      ('Zz', 'a1', 'a0'),
      (null, 'Y00', 'Xzzz'),
      ('bzz', null, 'c000'),
      ('a0', 'a0V', 'a0G'),
      ('a0', 'a0G', 'a08'),
      ('b125', 'b129', 'b127'),
      ('a0', 'a1V', 'a1'),
      ('Zz', 'a01', 'a0'),
      (null, 'a0V', 'a0'),
      (null, 'b999', 'b99'),
      (null, 'A00000000000000000000000000V', 'A00000000000000000000000000G'),
      (null, 'A000000000000000000000000001', 'A000000000000000000000000000V'),
      ('zzzzzzzzzzzzzzzzzzzzzzzzzzy', null, 'zzzzzzzzzzzzzzzzzzzzzzzzzzz'),
      ('zzzzzzzzzzzzzzzzzzzzzzzzzzz', null, 'zzzzzzzzzzzzzzzzzzzzzzzzzzzV'),
    ];

    for (final (a, b, expected) in cases) {
      test('($a, $b) -> $expected', () {
        final key = generateKeyBetween(a, b);
        expect(key, expected);
        if (a != null) expect(a.compareTo(key), lessThan(0));
        if (b != null) expect(key.compareTo(b), lessThan(0));
      });
    }

    test('rejects invalid input', () {
      expect(() => generateKeyBetween('a1', 'a0'), throwsArgumentError);
      expect(() => generateKeyBetween('a0', 'a0'), throwsArgumentError);
      expect(() => generateKeyBetween('a00', null), throwsArgumentError);
      expect(() => generateKeyBetween('a1 ', null), throwsArgumentError);
      expect(
        () => generateKeyBetween(null, 'A00000000000000000000000000'),
        throwsArgumentError,
      );
    });

    test('random inserts keep keys unique and ordered', () {
      final random = Random(42);
      final keys = <String>[generateKeyBetween(null, null)];
      for (var i = 0; i < 2000; i++) {
        final index = random.nextInt(keys.length + 1);
        final before = index == 0 ? null : keys[index - 1];
        final after = index == keys.length ? null : keys[index];
        keys.insert(index, generateKeyBetween(before, after));
      }
      final sorted = [...keys]..sort();
      expect(keys, sorted);
      expect(keys.toSet(), hasLength(keys.length));
      expect(keys.every(isValidOrderKey), isTrue);
    });

    test('repeated inserts at the front stay short-ish', () {
      String? first;
      for (var i = 0; i < 100; i++) {
        first = generateKeyBetween(null, first);
      }
      expect(first!.length, lessThan(5));
    });
  });

  group('generateNKeysBetween', () {
    test('matches reference values', () {
      expect(generateNKeysBetween(null, null, 5), [
        'a0',
        'a1',
        'a2',
        'a3',
        'a4',
      ]);
      expect(generateNKeysBetween('a4', null, 3), ['a5', 'a6', 'a7']);
      expect(generateNKeysBetween(null, 'a0', 3), ['Zx', 'Zy', 'Zz']);
      expect(generateNKeysBetween('a0', 'a2', 3), ['a0V', 'a1', 'a1V']);
    });

    test('returns sorted keys within bounds', () {
      final keys = generateNKeysBetween('a0', 'a1', 50);
      expect(keys, [...keys]..sort());
      expect(keys.first.compareTo('a0'), greaterThan(0));
      expect(keys.last.compareTo('a1'), lessThan(0));
      expect(keys.toSet(), hasLength(50));
    });

    test('n <= 0 is empty', () {
      expect(generateNKeysBetween(null, null, 0), isEmpty);
    });
  });
}
