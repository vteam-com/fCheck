import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_delegate.dart';
import 'package:test/test.dart';

AnalysisFileContext _contextForFile(File file) {
  final content = file.readAsStringSync();
  final parseResult = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  return AnalysisFileContext(
    file: file,
    content: content,
    parseResult: parseResult,
    lines: content.split('\n'),
    compilationUnit: parseResult.unit,
    hasParseErrors: parseResult.errors.isNotEmpty,
  );
}

void main() {
  group('CodeSizeDelegate', () {
    late Directory tempDir;
    late CodeSizeDelegate delegate;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_code_size_');
      delegate = CodeSizeDelegate();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('skips generated localization root file app_localization.dart', () {
      final file = File('${tempDir.path}/app_localization.dart')
        ..writeAsStringSync('''
class GeneratedLocalization {
  String value() => 'x';
}
''');

      final fileData = delegate.analyzeFileWithContext(_contextForFile(file));
      expect(fileData.artifacts, isEmpty);
    });
  });
}
