import 'dart:io';
import 'dart:math';

import 'package:fcheck/src/analyzers/secrets/secret_scanner.dart';
import 'package:test/test.dart';

/// Reference copy of the pre-optimization scanner (fcheck 1.6.0): every regex
/// is built per call and run on every line, with no literal pre-checks and a
/// regex-based high-entropy search. The optimized [SecretScanner] must report
/// exactly the same findings, in the same order, for any input.
List<String> _referenceFindings(String line) {
  double entropy(String str) {
    if (str.isEmpty) return 0.0;
    final counts = <String, int>{};
    for (final char in str.runes) {
      final charStr = String.fromCharCode(char);
      counts[charStr] = (counts[charStr] ?? 0) + 1;
    }
    double result = 0.0;
    for (final count in counts.values) {
      final probability = count / str.length;
      result -= probability * (log(probability) / ln2);
    }
    return result;
  }

  bool anyCandidate(RegExp regex, bool Function(String) isMatch) =>
      regex.allMatches(line).any((m) => isMatch(m.group(0) ?? ''));

  bool genericSecret() {
    final keywordRegex = RegExp(
      r'api[_-]?key|token|secret|password|private_key',
      caseSensitive: false,
    );
    final assignmentRegex = RegExp(
      "([\\w\$\"'.-]+)\\s*[:=]\\s*r?(['\"])([^'\"]+)\\2",
      caseSensitive: false,
    );
    final tripleQuoteRegex = RegExp(
      "([\\w\$\"'.-]+)\\s*[:=]\\s*r?('''|\"\"\")(.+?)\\2",
      caseSensitive: false,
    );
    final candidates = <String>[];
    for (final regex in [assignmentRegex, tripleQuoteRegex]) {
      for (final match in regex.allMatches(line)) {
        if (!keywordRegex.hasMatch(match.group(1) ?? '')) continue;
        final candidate = match.group(3) ?? '';
        if (candidate.isNotEmpty) candidates.add(candidate);
      }
    }
    return candidates.any((c) => c.length >= 20 && entropy(c) > 4.0);
  }

  return [
    if (anyCandidate(
      RegExp(r'AKIA[0-9A-Z]{16}'),
      (c) => c.length == 20 && entropy(c) > 3.5,
    ))
      'aws_access_key',
    if (genericSecret()) 'generic_secret',
    if (anyCandidate(
      RegExp('Bearer\\s+[a-zA-Z0-9_\\-]{20,}', caseSensitive: false),
      (c) => entropy(c) > 3.8,
    ))
      'bearer_token',
    if (RegExp(
      r'-----BEGIN\s+(RSA|EC|DSA|OPENSSH)\s+PRIVATE\s+KEY-----',
      caseSensitive: false,
    ).hasMatch(line))
      'private_key',
    if (RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      caseSensitive: false,
    ).hasMatch(line))
      'email_pii',
    if (RegExp(r'(sk_live_|pk_live_)[0-9a-zA-Z]{24}').hasMatch(line))
      'stripe_key',
    if (anyCandidate(
      RegExp(r'gh[p|s|o|u|l]_[0-9a-zA-Z]{36}|[gG]ithub_pat_'),
      (c) => c.length >= 40,
    ))
      'github_pat',
    if (anyCandidate(RegExp(r'[a-zA-Z0-9+/]{32,}'), (c) => entropy(c) > 4.5))
      'high_entropy',
  ];
}

/// Findings of the optimized scanner for a single [line].
List<String> _optimizedFindings(SecretScanner scanner, String line) => scanner
    .analyzeLines(filePath: 'f.dart', lines: [line])
    .map((issue) => issue.secretType ?? '')
    .toList();

/// Builds a random high-entropy run of [length] base64-like characters.
String _randomRun(Random random, int length) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  return String.fromCharCodes(
    List.generate(
      length,
      (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    ),
  );
}

/// Generates [count] lines mixing every detector's trigger fragments, quotes,
/// separators, case variants and non-ASCII characters.
List<String> _fuzzLines(int count) {
  final random = Random(42);
  final fragments = <String>[
    'AKIA',
    'AKIA${_randomRun(random, 16).toUpperCase()}',
    'Bearer ',
    'bearer\t',
    'BEARER  ',
    '-----BEGIN RSA PRIVATE KEY-----',
    '-----begin ec private key-----',
    '-----BEGIN  OPENSSH  PRIVATE KEY-----',
    '-----',
    '@',
    'user@example.com',
    'a.b@c.io',
    'x@y',
    'sk_live_',
    'pk_live_',
    '_live_',
    'ghp_',
    'gh|_',
    'ghs_',
    'Github_pat_',
    'github_pat_',
    'api_key',
    'API-KEY',
    'apikey',
    'token',
    'Token',
    'SECRET',
    'password',
    'private_key',
    'myToken',
    ' = ',
    '=',
    ': ',
    ':',
    "'",
    '"',
    "'''",
    '"""',
    'r',
    ' ',
    '\t',
    '.',
    '-',
    '_',
    r'$',
    'é',
    '😀',
    '+',
    '/',
    'abc',
    'ZZZZ',
  ];
  return List.generate(count, (_) {
    final buffer = StringBuffer();
    final parts = random.nextInt(12);
    for (var i = 0; i < parts; i++) {
      if (random.nextInt(4) == 0) {
        buffer.write(_randomRun(random, 16 + random.nextInt(28)));
      } else {
        buffer.write(fragments[random.nextInt(fragments.length)]);
      }
    }
    return buffer.toString();
  });
}

void main() {
  final scanner = SecretScanner();

  void expectSameAsReference(Iterable<String> lines) {
    var checked = 0;
    for (final line in lines) {
      expect(
        _optimizedFindings(scanner, line),
        _referenceFindings(line),
        reason: 'line: $line',
      );
      checked++;
    }
    expect(checked, greaterThan(0));
  }

  group('SecretScanner matches the reference implementation', () {
    test('on detector boundary cases', () {
      final random = Random(7);
      final run31 = _randomRun(random, 31);
      final run32 = _randomRun(random, 32);
      final run40 = _randomRun(random, 40);
      expectSameAsReference([
        '',
        run31,
        run32,
        run40,
        '$run32 $run31',
        '"$run40"',
        'x=$run32;',
        '$run31é$run31',
        '$run32😀',
        'final apiKey = "$run40";',
        'final value = "$run40"; // token',
        "final token = '''$run40''';",
        "final password = r'$run40';",
        'headers: {"Authorization": "Bearer $run40"}',
        'BEARER $run40',
        '-----begin rsa private key-----',
        '----- BEGIN RSA PRIVATE KEY -----',
        'contact me at jp@example.com',
        'no at sign example.com',
        'sk_live_${run32.substring(0, 24)}',
        'SK_LIVE_${run32.substring(0, 24)}',
        'pk_live_${run40.substring(0, 24)}',
        'ghp_${run40.substring(0, 36)}',
        'github_pat_x',
        'AKIA${run32.substring(0, 16).toUpperCase()}',
        'akia${run32.substring(0, 16).toUpperCase()}',
      ]);
    });

    test('on 20,000 seeded fuzz lines', () {
      expectSameAsReference(_fuzzLines(20000));
    });

    test('on every line of this repository', () {
      final lines = <String>[
        for (final dir in ['lib', 'test', 'bin'])
          for (final entity in Directory(dir).listSync(recursive: true))
            if (entity is File && entity.path.endsWith('.dart'))
              ...entity.readAsLinesSync(),
      ];
      expectSameAsReference(lines);
    });
  });
}
