import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzers/sorted/sort_members.dart';
import 'package:test/test.dart';

ClassDeclaration _parseFirstClass(String content) {
  final result = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  return result.unit.declarations.whereType<ClassDeclaration>().first;
}

void main() {
  group('MemberSorter', () {
    test('returns empty body for class without members', () {
      const source = 'class Empty {}';
      final classNode = _parseFirstClass(source);
      final sorter =
          MemberSorter(source, (classNode.body as BlockClassBody).members);

      expect(sorter.getSortedBody(), equals(''));
    });

    test(
        'sorts constructor and grouped fields first, then lifecycle/public/private methods',
        () {
      const source = '''
class Sample {
  int b = 2;
  void zebra() {}
  int get b => b;
  int a = 1;
  Sample.named();
  int get a => a;
  void _zebra() {}
  set a(int value) {}
  void apple() {}
  void build() {}
  void _apple() {}
  void initState() {}
  void dispose() {}
}
''';

      final classNode = _parseFirstClass(source);
      final sorter =
          MemberSorter(source, (classNode.body as BlockClassBody).members);
      final sorted = sorter.getSortedBody();

      expect(sorted.startsWith('\n'), isTrue);
      expect(sorted.endsWith('\n'), isTrue);

      // Constructor stays in non-method section and appears before sorted fields.
      expect(sorted.indexOf('Sample.named();'),
          lessThan(sorted.indexOf('int a = 1;')));

      // Fields are sorted alphabetically and keep accessors attached to each field.
      expect(
          sorted.indexOf('int a = 1;'), lessThan(sorted.indexOf('int b = 2;')));
      expect(sorted.indexOf('int get a => a;'),
          lessThan(sorted.indexOf('int b = 2;')));
      expect(sorted.indexOf('set a(int value) {}'),
          lessThan(sorted.indexOf('int b = 2;')));
      expect(sorted.indexOf('int get b => b;'),
          greaterThan(sorted.indexOf('int b = 2;')));

      // Lifecycle methods follow fixed order.
      expect(sorted.indexOf('void initState() {}'),
          lessThan(sorted.indexOf('void dispose() {}')));
      expect(sorted.indexOf('void dispose() {}'),
          lessThan(sorted.indexOf('void build() {}')));

      // Public and private methods are alphabetical inside their groups.
      expect(sorted.indexOf('void apple() {}'),
          lessThan(sorted.indexOf('void zebra() {}')));
      expect(sorted.indexOf('void _apple() {}'),
          lessThan(sorted.indexOf('void _zebra() {}')));

      // Accessors are grouped with fields and not repeated in method groups.
      expect(RegExp(r'int get a => a;').allMatches(sorted).length, equals(1));
      expect(RegExp(r'int get b => b;').allMatches(sorted).length, equals(1));
      expect(RegExp(r'set a\(int value\) \{\}').allMatches(sorted).length,
          equals(1));
    });
  });
}
