import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const double _configuredSimilarity = 0.85;
const int _configuredMinTokens = 30;
const int _configuredMinLines = 12;
const int _configuredMaxClassLoc = 400;
const String _extraExclude = '**/*.g.dart';
const double _overriddenSimilarity = 0.7;
const int _overriddenMinLines = 6;

void main() {
  group('AnalyzeFolder.fromConfig', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_from_config_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('applies the .fcheck settings the CLI applies', () {
      File(p.join(tempDir.path, FcheckConfig.fileName)).writeAsStringSync('''
input:
  root: app
  exclude:
    - "**/generated/**"
analyzers:
  disabled:
    - hardcoded_strings
  options:
    duplicate_code:
      similarity_threshold: $_configuredSimilarity
      min_tokens: $_configuredMinTokens
      min_non_empty_lines: $_configuredMinLines
    code_size:
      max_class_loc: $_configuredMaxClassLoc
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final engine = AnalyzeFolder.fromConfig(
        config,
        extraExcludePatterns: [_extraExclude],
      );

      expect(
        engine.projectDir.path,
        equals(p.normalize(p.join(tempDir.absolute.path, 'app'))),
      );
      expect(
        engine.excludePatterns,
        equals(['**/generated/**', _extraExclude]),
      );
      expect(
        engine.enabledAnalyzers,
        isNot(contains(AnalyzerDomain.hardcodedStrings)),
      );
      expect(
        engine.duplicateCodeSimilarityThreshold,
        equals(_configuredSimilarity),
      );
      expect(engine.duplicateCodeMinTokenCount, equals(_configuredMinTokens));
      expect(
        engine.duplicateCodeMinNonEmptyLineCount,
        equals(_configuredMinLines),
      );
      expect(
        engine.codeSizeThresholds.maxClassLoc,
        equals(_configuredMaxClassLoc),
      );
      expect(engine.fix, isFalse);
    });

    test('lets callers override the duplicate-code thresholds', () {
      final engine = AnalyzeFolder.fromConfig(
        FcheckConfig.loadForInputDirectory(tempDir),
        duplicateCodeSimilarityThreshold: _overriddenSimilarity,
        duplicateCodeMinNonEmptyLineCount: _overriddenMinLines,
      );

      expect(
        engine.duplicateCodeSimilarityThreshold,
        equals(_overriddenSimilarity),
      );
      expect(
        engine.duplicateCodeMinNonEmptyLineCount,
        equals(_overriddenMinLines),
      );
    });

    test('analyzes a project through the public API', () {
      File(p.join(tempDir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: sample\n');
      Directory(p.join(tempDir.path, 'lib')).createSync();
      File(p.join(tempDir.path, 'lib', 'sample.dart'))
          .writeAsStringSync('/// Sample.\nclass Sample {}\n');

      final metrics = AnalyzeFolder.fromConfig(
        FcheckConfig.loadForInputDirectory(tempDir),
      ).analyze();

      expect(metrics.totalDartFiles, equals(1));
      expect(metrics.duplicateCodeIssues, isEmpty);
    });
  });
}
