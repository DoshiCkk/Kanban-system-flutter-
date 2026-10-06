/// Fractional indexing: string keys that sort lexicographically (by code
/// unit, i.e. SQLite BINARY / Postgres `COLLATE "C"`) and allow inserting a
/// key between any two others. Moving a card therefore rewrites one row.
///
/// Port of https://github.com/rocicorp/fractional-indexing (CC0) by
/// David Greenspan / Rocicorp, based on
/// https://observablehq.com/@dgreensp/implementing-fractional-indexing.
///
/// A key is an "integer part" (head char `a`–`z` / `A`–`Z` encoding its
/// length, then base-62 digits) followed by an optional fraction that never
/// ends in `0`.
library;

const base62Digits =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

const _zero = '0';
final _smallestInteger = 'A${_zero * 26}';

/// Returns a key strictly between [a] and [b].
///
/// `null` means "no bound": `(null, null)` is the first key of an empty list,
/// `(last, null)` appends, `(null, first)` prepends.
/// Throws [ArgumentError] if `a >= b` or a key is malformed.
String generateKeyBetween(String? a, String? b) {
  if (a != null) _validateOrderKey(a);
  if (b != null) _validateOrderKey(b);
  if (a != null && b != null && a.compareTo(b) >= 0) {
    throw ArgumentError('$a >= $b');
  }

  if (a == null) {
    if (b == null) return 'a$_zero';
    final ib = _integerPart(b);
    final fb = b.substring(ib.length);
    if (ib == _smallestInteger) return ib + _midpoint('', fb);
    if (ib.compareTo(b) < 0) return ib;
    final res = _decrementInteger(ib);
    if (res == null) throw StateError('Cannot decrement any more');
    return res;
  }

  if (b == null) {
    final ia = _integerPart(a);
    final fa = a.substring(ia.length);
    final i = _incrementInteger(ia);
    return i ?? ia + _midpoint(fa, null);
  }

  final ia = _integerPart(a);
  final fa = a.substring(ia.length);
  final ib = _integerPart(b);
  final fb = b.substring(ib.length);
  if (ia == ib) return ia + _midpoint(fa, fb);
  final i = _incrementInteger(ia);
  if (i == null) throw StateError('Cannot increment any more');
  if (i.compareTo(b) < 0) return i;
  return ia + _midpoint(fa, null);
}

/// Returns [n] sorted keys strictly between [a] and [b], spread evenly when
/// both bounds are given.
List<String> generateNKeysBetween(String? a, String? b, int n) {
  if (n <= 0) return const [];
  if (n == 1) return [generateKeyBetween(a, b)];
  if (b == null) {
    var c = generateKeyBetween(a, b);
    final result = [c];
    for (var i = 0; i < n - 1; i++) {
      c = generateKeyBetween(c, b);
      result.add(c);
    }
    return result;
  }
  if (a == null) {
    var c = generateKeyBetween(a, b);
    final result = [c];
    for (var i = 0; i < n - 1; i++) {
      c = generateKeyBetween(a, c);
      result.add(c);
    }
    return result.reversed.toList();
  }
  final mid = n ~/ 2;
  final c = generateKeyBetween(a, b);
  return [
    ...generateNKeysBetween(a, c, mid),
    c,
    ...generateNKeysBetween(c, b, n - mid - 1),
  ];
}

/// Whether [key] is a well-formed order key.
bool isValidOrderKey(String key) {
  try {
    _validateOrderKey(key);
    return true;
    // Validation reports problems as ArgumentError; map it to a bool here.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return false;
  }
}

String _midpoint(String a, String? b) {
  if (b != null && a.compareTo(b) >= 0) throw ArgumentError('$a >= $b');
  if (a.endsWith(_zero) || (b != null && b.endsWith(_zero))) {
    throw ArgumentError('trailing zero');
  }
  if (b != null) {
    // Shared prefix (a padded with zeros).
    var n = 0;
    while (n < b.length && (n < a.length ? a[n] : _zero) == b[n]) {
      n++;
    }
    if (n > 0) {
      return b.substring(0, n) +
          _midpoint(
            n < a.length ? a.substring(n) : '',
            b.substring(n),
          );
    }
  }
  final digitA = a.isNotEmpty ? base62Digits.indexOf(a[0]) : 0;
  final digitB = b != null ? base62Digits.indexOf(b[0]) : base62Digits.length;
  if (digitB - digitA > 1) {
    return base62Digits[(0.5 * (digitA + digitB)).round()];
  }
  if (b != null && b.length > 1) return b.substring(0, 1);
  final rest = a.isEmpty ? '' : a.substring(1);
  return base62Digits[digitA] + _midpoint(rest, null);
}

int _integerLength(String head) {
  final c = head.codeUnitAt(0);
  if (c >= 0x61 && c <= 0x7A) return c - 0x61 + 2; // a..z
  if (c >= 0x41 && c <= 0x5A) return 0x5A - c + 2; // A..Z
  throw ArgumentError('invalid order key head: $head');
}

void _validateInteger(String i) {
  if (i.length != _integerLength(i[0])) {
    throw ArgumentError('invalid integer part of order key: $i');
  }
}

String _integerPart(String key) {
  final length = _integerLength(key[0]);
  if (length > key.length) throw ArgumentError('invalid order key: $key');
  return key.substring(0, length);
}

void _validateOrderKey(String key) {
  if (key.isEmpty) throw ArgumentError('empty order key');
  if (key == _smallestInteger) throw ArgumentError('invalid order key: $key');
  for (final unit in key.codeUnits) {
    if (!base62Digits.contains(String.fromCharCode(unit))) {
      throw ArgumentError('invalid character in order key: $key');
    }
  }
  final i = _integerPart(key);
  final f = key.substring(i.length);
  if (f.endsWith(_zero)) throw ArgumentError('invalid order key: $key');
}

String? _incrementInteger(String x) {
  _validateInteger(x);
  final head = x[0];
  final digs = x.substring(1).split('');
  var carry = true;
  for (var i = digs.length - 1; carry && i >= 0; i--) {
    final d = base62Digits.indexOf(digs[i]) + 1;
    if (d == base62Digits.length) {
      digs[i] = _zero;
    } else {
      digs[i] = base62Digits[d];
      carry = false;
    }
  }
  if (carry) {
    if (head == 'Z') return 'a$_zero';
    if (head == 'z') return null;
    final h = String.fromCharCode(head.codeUnitAt(0) + 1);
    if (h.compareTo('a') > 0) {
      digs.add(_zero);
    } else {
      digs.removeLast();
    }
    return h + digs.join();
  }
  return head + digs.join();
}

String? _decrementInteger(String x) {
  _validateInteger(x);
  final head = x[0];
  final digs = x.substring(1).split('');
  final last = base62Digits[base62Digits.length - 1];
  var borrow = true;
  for (var i = digs.length - 1; borrow && i >= 0; i--) {
    final d = base62Digits.indexOf(digs[i]) - 1;
    if (d == -1) {
      digs[i] = last;
    } else {
      digs[i] = base62Digits[d];
      borrow = false;
    }
  }
  if (borrow) {
    if (head == 'a') return 'Z$last';
    if (head == 'A') return null;
    final h = String.fromCharCode(head.codeUnitAt(0) - 1);
    if (h.compareTo('Z') < 0) {
      digs.add(last);
    } else {
      digs.removeLast();
    }
    return h + digs.join();
  }
  return head + digs.join();
}
