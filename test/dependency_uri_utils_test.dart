import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzers/shared/dependency_uri_utils.dart';
import 'package:test/test.dart';

void main() {
  group('isProjectDartDependencyUri', () {
    const packageName = 'my_app';

    test('returns false for SDK URIs', () {
      expect(
        isProjectDartDependencyUri(uri: 'dart:core', packageName: packageName),
        isFalse,
      );
    });

    test('returns false for external package URIs', () {
      expect(
        isProjectDartDependencyUri(
          uri: 'package:other_pkg/main.dart',
          packageName: packageName,
        ),
        isFalse,
      );
    });

    test('returns true for same-package Dart URIs', () {
      expect(
        isProjectDartDependencyUri(
          uri: 'package:my_app/src/main.dart',
          packageName: packageName,
        ),
        isTrue,
      );
    });

    test('returns false for same-package non-Dart URIs', () {
      expect(
        isProjectDartDependencyUri(
          uri: 'package:my_app/assets/icon.svg',
          packageName: packageName,
        ),
        isFalse,
      );
    });

    test('returns true for relative Dart URIs', () {
      expect(
        isProjectDartDependencyUri(
          uri: '../shared/helper.dart',
          packageName: packageName,
        ),
        isTrue,
      );
    });

    test('returns false for relative non-Dart URIs', () {
      expect(
        isProjectDartDependencyUri(
          uri: '../shared/helper.json',
          packageName: packageName,
        ),
        isFalse,
      );
    });
  });

  group('resolveProjectDependencyUri', () {
    const rootPath = '/workspace/project';
    const packageName = 'my_app';
    const currentFile = '/workspace/project/lib/feature/main.dart';

    test('resolves same-package package URI into lib path', () {
      final resolved = resolveProjectDependencyUri(
        uri: 'package:my_app/utils/a.dart',
        currentFile: currentFile,
        rootPath: rootPath,
        packageName: packageName,
      );

      expect(resolved, equals('/workspace/project/lib/utils/a.dart'));
    });

    test('resolves current-directory relative URI', () {
      final resolved = resolveProjectDependencyUri(
        uri: './widgets/card.dart',
        currentFile: currentFile,
        rootPath: rootPath,
        packageName: packageName,
      );

      expect(
        resolved,
        equals('/workspace/project/lib/feature/widgets/card.dart'),
      );
    });

    test('resolves parent-directory relative URI with multiple segments', () {
      final resolved = resolveProjectDependencyUri(
        uri: '../../shared/types.dart',
        currentFile: currentFile,
        rootPath: rootPath,
        packageName: packageName,
      );

      expect(resolved, equals('/workspace/project/shared/types.dart'));
    });

    test('resolves plain local URI against current directory', () {
      final resolved = resolveProjectDependencyUri(
        uri: 'local_file.dart',
        currentFile: currentFile,
        rootPath: rootPath,
        packageName: packageName,
      );

      expect(
        resolved,
        equals('/workspace/project/lib/feature/local_file.dart'),
      );
    });
  });

  group('addDirectiveDartDependencies', () {
    const packageName = 'my_app';
    const filePath = '/workspace/project/lib/feature/main.dart';
    const rootPath = '/workspace/project';

    test(
      'adds only project-scoped Dart dependencies from import and configs',
      () {
        const source = '''
import 'src/base.dart'
    if (dart.library.io) 'src/io.dart'
    if (dart.library.js) 'package:my_app/shared.dart'
    if (dart.library.html) 'package:other_pkg/web.dart'
    if (dart.library.ffi) 'dart:ffi';
''';
        final importDirective = _parseFirstImportDirective(source);
        final dependencies = <String>[];

        addDirectiveDartDependencies(
          uri: importDirective.uri.stringValue,
          configurations: importDirective.configurations,
          packageName: packageName,
          filePath: filePath,
          rootPath: rootPath,
          dependencies: dependencies,
        );

        expect(
          dependencies,
          equals([
            '/workspace/project/lib/feature/src/base.dart',
            '/workspace/project/lib/feature/src/io.dart',
            '/workspace/project/lib/shared.dart',
          ]),
        );
      },
    );

    test(
      'returns without changes for non-project primary URI and empty configs',
      () {
        final dependencies = <String>[];

        addDirectiveDartDependencies(
          uri: 'package:external_pkg/a.dart',
          configurations: const <Configuration>[],
          packageName: packageName,
          filePath: filePath,
          rootPath: rootPath,
          dependencies: dependencies,
        );

        expect(dependencies, isEmpty);
      },
    );
  });
}

ImportDirective _parseFirstImportDirective(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  return result.unit.directives.whereType<ImportDirective>().first;
}
