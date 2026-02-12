import 'package:fcheck/src/models/ignore_config.dart';
import 'package:test/test.dart';

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

      expect(IgnoreConfig.countFcheckIgnoreDirectives(content), equals(3));
    });

    test('counts multiple fcheck directives on one ignore line', () {
      const content = '''
// ignore: fcheck_magic_numbers, fcheck_hardcoded_strings
final answer = 42;
''';

      expect(IgnoreConfig.countFcheckIgnoreDirectives(content), equals(2));
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

      expect(IgnoreConfig.countFcheckIgnoreDirectives(content), equals(0));
    });

    test('does not count ignore-like text inside documentation comments', () {
      const content = '''
/// `// ignore: fcheck_layers` is an example in docs.
/// Another note with `// ignore: fcheck_magic_numbers`.
class Example {}
''';

      expect(IgnoreConfig.countFcheckIgnoreDirectives(content), equals(0));
    });
  });
}
