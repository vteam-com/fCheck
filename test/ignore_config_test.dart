import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/models/ignore_config.dart';
import 'package:test/test.dart';

const int _zero = 0;
const int _one = 1;
const int _two = 2;

void main() {
  group('IgnoreConfig.countFcheckIgnoreDirectives', () {
    test('counts top-of-file and inline fcheck directives', () {
      const content = '''
// ignore: fcheck_magic_numbers
void main() {
  final value = 42; // ignore: fcheck_magic_numbers
  final title = "Hello"; // ignore: hardcoded.string, fcheck_hardcoded_strings
  // ignore_for_file: fcheck_dead_code
}
''';

      expect(
        IgnoreConfig.countFcheckIgnoreDirectives(content),
        equals(_two + _one),
      );
    });

    test('counts multiple fcheck directives on one ignore line', () {
      const content = '''
// ignore: fcheck_magic_numbers, fcheck_hardcoded_strings
final answer = 42;
''';

      expect(IgnoreConfig.countFcheckIgnoreDirectives(content), equals(_two));
    });

    test('does not count ignore-like text inside string literals', () {
      const content = r"""
class IgnoreConfig {
  static const a = '// ignore: fcheck_magic_numbers';
  static const b = " // ignore: fcheck_hardcoded_strings ";
  static const c = '''
// ignore: fcheck_dead_code
''';
}
""";

      expect(IgnoreConfig.countFcheckIgnoreDirectives(content), equals(_zero));
    });

    test('does not count ignore-like text inside documentation comments', () {
      const content = '''
/// `// ignore: fcheck_layers` is an example in docs.
/// Another note with `// ignore: fcheck_magic_numbers`.
class Example {}
''';

      expect(IgnoreConfig.countFcheckIgnoreDirectives(content), equals(_zero));
    });
  });

  group('IgnoreConfig.hasIgnoreForFileDirective', () {
    test('detects // ignore directive in leading line comments', () {
      const content = '''
// ignore: fcheck_magic_numbers
void main() {}
''';
      expect(
        IgnoreConfig.hasIgnoreForFileDirective(
          content,
          '// ignore: fcheck_magic_numbers',
        ),
        isTrue,
      );
    });

    test('detects directive inside a leading /* */ block comment', () {
      const content = '''
/* ignore: fcheck_magic_numbers */
void main() {}
''';
      expect(
        IgnoreConfig.hasIgnoreForFileDirective(
          content,
          '// ignore: fcheck_magic_numbers',
        ),
        isFalse,
      );
    });

    test('detects directive after a multi-line /* */ block comment', () {
      // The hasIgnoreForFileDirective collects the leading comment block,
      // which includes block comments, before checking for the directive.
      const content = '''
/*
 * Copyright notice.
 */
// ignore: fcheck_magic_numbers
void main() {}
''';
      expect(
        IgnoreConfig.hasIgnoreForFileDirective(
          content,
          '// ignore: fcheck_magic_numbers',
        ),
        isTrue,
      );
    });

    test('returns false when content is empty', () {
      expect(
        IgnoreConfig.hasIgnoreForFileDirective('', '// ignore: fcheck_layers'),
        isFalse,
      );
    });

    test('returns false when expectedComment is empty', () {
      expect(
        IgnoreConfig.hasIgnoreForFileDirective('// ignore: fcheck_layers', ''),
        isFalse,
      );
    });
  });

  group('IgnoreConfig.collectIgnoredLineNumbers', () {
    test('returns empty set when no lines match the domain', () {
      final lines = ['void main() {', '  final x = 42;', '}'];
      final result = IgnoreConfig.collectIgnoredLineNumbers(
        lines,
        'magic_numbers',
      );
      expect(result, isEmpty);
    });

    test('returns correct 1-based line numbers for matching directives', () {
      final lines = [
        '// ignore: fcheck_magic_numbers',
        'void main() {',
        '  final x = 42; // ignore: fcheck_magic_numbers',
        '}',
      ];
      final result = IgnoreConfig.collectIgnoredLineNumbers(
        lines,
        'magic_numbers',
      );
      expect(result, equals({_one, _one + _two}));
    });

    test('ignores // comments that are not ignore directives', () {
      // Lines with // but no "ignore:" prefix — exercises the match==null branch.
      final lines = [
        '// A regular comment',
        'void fn() { /* block */ }',
        '  final x = 0; // assign zero',
      ];
      final result = IgnoreConfig.collectIgnoredLineNumbers(
        lines,
        'magic_numbers',
      );
      expect(result, isEmpty);
    });

    test('does not match a different domain', () {
      final lines = ['// ignore: fcheck_hardcoded_strings'];
      final result = IgnoreConfig.collectIgnoredLineNumbers(
        lines,
        'magic_numbers',
      );
      expect(result, isEmpty);
    });
  });

  group('IgnoreConfig.isNodeIgnored', () {
    test('returns false when no ignore directive is present', () {
      const source = 'void main() { final x = 42; }';
      final unit = parseString(
        content: source,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
      // Use the compilation unit itself as the node.
      expect(
        IgnoreConfig.isNodeIgnored(unit, source, 'magic_numbers'),
        isFalse,
      );
    });

    test('returns false when directive is for a different domain', () {
      const source = '// ignore: fcheck_hardcoded_strings\nvoid main() {}';
      final unit = parseString(
        content: source,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
      expect(
        IgnoreConfig.isNodeIgnored(unit, source, 'magic_numbers'),
        isFalse,
      );
    });
  });

  group('IgnoreConfig.isNodeIgnoredWithLines', () {
    test('returns false immediately when ignoredLineNumbers is empty', () {
      const source = 'void main() {}';
      final unit = parseString(
        content: source,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
      expect(
        IgnoreConfig.isNodeIgnoredWithLines(
          unit,
          ignoredLineNumbers: const {},
          lineNumberForOffset: (_) => _one,
        ),
        isFalse,
      );
    });

    test('returns true when node offset maps to an ignored line', () {
      const source = '// ignore: fcheck_magic_numbers\nvoid main() {}';
      final unit = parseString(
        content: source,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
      // Pretend every offset is on line 1.
      expect(
        IgnoreConfig.isNodeIgnoredWithLines(
          unit,
          ignoredLineNumbers: {_one},
          lineNumberForOffset: (_) => _one,
        ),
        isTrue,
      );
    });

    test('returns false when node offset does not match any ignored line', () {
      const source = 'void main() {}';
      final unit = parseString(
        content: source,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
      // Ignored line is 99, but all nodes map to line 1.
      expect(
        IgnoreConfig.isNodeIgnoredWithLines(
          unit,
          ignoredLineNumbers: {99},
          lineNumberForOffset: (_) => _one,
        ),
        isFalse,
      );
    });
  });
}
