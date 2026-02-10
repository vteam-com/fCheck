import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:test/test.dart';

void main() {
  group('Duplicate code analysis', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_duplicate_code_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reports snippets with similarity >= 85%', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
int calculateTotal(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 10) {
      total += value;
    } else {
      total += value * 2;
    }
  }
  return total;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
int sumItems(List<int> items) {
  var amount = 0;
  for (final item in items) {
    if (item > 10) {
      amount += item;
    } else {
      amount += item * 2;
    }
  }
  return amount;
}
''');

      final metrics = AnalyzeFolder(
        tempDir,
        duplicateCodeSimilarityThreshold: 0.85,
        duplicateCodeMinTokenCount: 1,
        duplicateCodeMinNonEmptyLineCount: 1,
      ).analyze();

      expect(metrics.duplicateCodeIssues, hasLength(1));
      final issue = metrics.duplicateCodeIssues.first;
      expect(issue.similarity, greaterThanOrEqualTo(0.85));
      expect(issue.firstSymbol, equals('calculateTotal'));
      expect(issue.secondSymbol, equals('sumItems'));
    });

    test('does not report snippets below similarity threshold', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
int calculateTotal(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 10) {
      total += value;
    } else {
      total += value * 2;
    }
  }
  return total;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
String describeItems(List<int> items) {
  if (items.isEmpty) {
    return 'none';
  }

  final sorted = [...items]..sort();
  return sorted.map((item) => 'value:\$item').join(',');
}
''');

      final metrics = AnalyzeFolder(
        tempDir,
        duplicateCodeSimilarityThreshold: 0.85,
        duplicateCodeMinTokenCount: 1,
        duplicateCodeMinNonEmptyLineCount: 1,
      ).analyze();

      expect(metrics.duplicateCodeIssues, isEmpty);
    });

    test('respects file-level ignore directive', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
// ignore: fcheck_duplicate_code
int calculateTotal(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 10) {
      total += value;
    } else {
      total += value * 2;
    }
  }
  return total;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
int sumItems(List<int> items) {
  var amount = 0;
  for (final item in items) {
    if (item > 10) {
      amount += item;
    } else {
      amount += item * 2;
    }
  }
  return amount;
}
''');

      final metrics = AnalyzeFolder(
        tempDir,
        duplicateCodeSimilarityThreshold: 0.85,
        duplicateCodeMinTokenCount: 1,
        duplicateCodeMinNonEmptyLineCount: 1,
      ).analyze();

      expect(metrics.duplicateCodeIssues, isEmpty);
    });

    test('can be disabled via enabled analyzer allowlist', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
int f(List<int> values) {
  var total = 0;
  for (final value in values) {
    total += value;
  }
  return total;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
int g(List<int> values) {
  var total = 0;
  for (final value in values) {
    total += value;
  }
  return total;
}
''');

      final metrics = AnalyzeFolder(
        tempDir,
        enabledAnalyzers: {
          AnalyzerDomain.magicNumbers,
        },
      ).analyze();

      expect(metrics.duplicateCodeAnalyzerEnabled, isFalse);
      expect(metrics.duplicateCodeIssues, isEmpty);
    });

    test('requires matching parameter signatures', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
int normalizeScore(int score, {bool clamp = false}) {
  var result = score * 2;
  result += 1;
  if (result > 100) {
    result = 100;
  }
  return result;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
int normalizeScoreLegacy(int score) {
  var result = score * 2;
  result += 1;
  if (result > 100) {
    result = 100;
  }
  return result;
}
''');

      final metrics = AnalyzeFolder(
        tempDir,
        duplicateCodeSimilarityThreshold: 0.85,
        duplicateCodeMinTokenCount: 1,
        duplicateCodeMinNonEmptyLineCount: 1,
      ).analyze();

      expect(metrics.duplicateCodeIssues, isEmpty);
    });

    test('sorts matches by similarity descending', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
int calculateTotal(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 10) {
      total += value;
    } else {
      total += value * 2;
    }
  }
  return total;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
int sumItems(List<int> items) {
  var amount = 0;
  for (final item in items) {
    if (item > 10) {
      amount += item;
    } else {
      amount += item * 2;
    }
  }
  return amount;
}
''');

      File('${tempDir.path}/third.dart').writeAsStringSync('''
int computeScore(List<int> numbers) {
  var score = 0;
  for (final number in numbers) {
    if (number > 10) {
      score += number;
    } else {
      score += number * 2;
    }
  }
  score += 0;
  return score;
}
''');

      final metrics = AnalyzeFolder(
        tempDir,
        duplicateCodeSimilarityThreshold: 0.85,
        duplicateCodeMinTokenCount: 1,
        duplicateCodeMinNonEmptyLineCount: 1,
      ).analyze();
      final issues = metrics.duplicateCodeIssues;

      expect(issues.length, greaterThanOrEqualTo(2));
      expect(issues.first.similarity, lessThanOrEqualTo(1.0));
      expect(issues.last.similarity, greaterThanOrEqualTo(0.85));
      for (var i = 1; i < issues.length; i++) {
        expect(
          issues[i - 1].similarity,
          greaterThanOrEqualTo(issues[i].similarity),
        );
      }
    });

    test('ignores very small duplicate functions by default', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
int a(int x) {
  return x + 1;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
int b(int x) {
  return x + 1;
}
''');

      final metrics = AnalyzeFolder(tempDir).analyze();

      expect(metrics.duplicateCodeIssues, isEmpty);
    });

    test('small duplicate functions can be enabled with lower thresholds', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
int a(int x) {
  return x + 1;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
int b(int x) {
  return x + 1;
}
''');

      final metrics = AnalyzeFolder(
        tempDir,
        duplicateCodeSimilarityThreshold: 0.85,
        duplicateCodeMinTokenCount: 1,
        duplicateCodeMinNonEmptyLineCount: 1,
      ).analyze();

      expect(metrics.duplicateCodeIssues, hasLength(1));
    });

    test('sorts equal-similarity matches by line count descending', () {
      File('${tempDir.path}/first.dart').writeAsStringSync('''
int firstFn(int x) {
  var y = x + 1;
  if (y > 10) {
    y = y * 2;
  }
  return y;
}
''');

      File('${tempDir.path}/second.dart').writeAsStringSync('''
int secondFn(int x) {
  var y = x + 1; if (y > 10) { y = y * 2; }
  return y;
}
''');

      File('${tempDir.path}/third.dart').writeAsStringSync('''
int thirdFn(int x) { var y = x + 1; if (y > 10) { y = y * 2; } return y; }
''');

      final metrics = AnalyzeFolder(
        tempDir,
        duplicateCodeSimilarityThreshold: 0.85,
        duplicateCodeMinTokenCount: 1,
        duplicateCodeMinNonEmptyLineCount: 1,
      ).analyze();
      final issues = metrics.duplicateCodeIssues;

      expect(issues, hasLength(3));
      expect(issues.every((issue) => issue.similarity == 1.0), isTrue);
      expect(issues[0].lineCount, equals(3));
      expect(issues[1].lineCount, equals(1));
      expect(issues[2].lineCount, equals(1));
    });
  });
}
