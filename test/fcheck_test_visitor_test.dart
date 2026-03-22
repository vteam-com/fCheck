import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/fcheck_test_visitor.dart';
import 'package:test/test.dart';

int _count(String source) {
  final parseResult = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = TestCaseVisitor();
  parseResult.unit.accept(visitor);
  return visitor.testCaseCount;
}

void main() {
  group('TestCaseVisitor', () {
    test('starts with testCaseCount of zero', () {
      expect(TestCaseVisitor().testCaseCount, equals(0));
    });

    test('counts zero for empty file', () {
      expect(_count('void main() {}'), equals(0));
    });

    // --- visitMethodInvocation: matching names ---

    test('counts a single test() call', () {
      const source = '''
void main() {
  test('example', () {});
}
''';
      expect(_count(source), equals(1));
    });

    test('counts a single testWidgets() call', () {
      const source = '''
void main() {
  testWidgets('widget test', (tester) async {});
}
''';
      expect(_count(source), equals(1));
    });

    test('counts multiple test() calls', () {
      const source = '''
void main() {
  test('first', () {});
  test('second', () {});
  test('third', () {});
}
''';
      expect(_count(source), equals(3));
    });

    test('counts mixed test() and testWidgets() calls', () {
      const source = '''
void main() {
  test('unit', () {});
  testWidgets('widget', (tester) async {});
  test('unit2', () {});
}
''';
      expect(_count(source), equals(3));
    });

    test('counts tests nested inside a group', () {
      const source = '''
void main() {
  group('suite', () {
    test('a', () {});
    test('b', () {});
    testWidgets('c', (tester) async {});
  });
}
''';
      expect(_count(source), equals(3));
    });

    // --- visitMethodInvocation: non-matching names ---

    test('does not count setUp, tearDown, group, or expect', () {
      const source = '''
void main() {
  setUp(() {});
  tearDown(() {});
  group('g', () {});
  expect(1, equals(1));
  setUpAll(() {});
  tearDownAll(() {});
}
''';
      expect(_count(source), equals(0));
    });

    test('does not count similarly-named functions like testHelper', () {
      const source = '''
void testHelper() {}
void main() {
  testHelper();
}
''';
      expect(_count(source), equals(0));
    });

    // --- visitFunctionExpressionInvocation ---

    // --- FunctionExpressionInvocation (parenthesised / complex calls) ---

    test('does not count parenthesised or IIFE-style function calls', () {
      // Dart parses `identifier(args)` as MethodInvocation; only complex
      // expressions like `(fn)(args)` or `(() {})(args)` produce
      // FunctionExpressionInvocation. Neither should be counted.
      const source = '''
void main() {
  (() => null)();
  (print)('hello');
}
''';
      expect(_count(source), equals(0));
    });
  });
}
