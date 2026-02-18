import 'dart:io';

import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FcheckConfig', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_config_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns defaults when .fcheck does not exist', () {
      final config = FcheckConfig.loadForInputDirectory(tempDir);

      expect(config.sourceFile, isNull);
      expect(config.excludePatterns, isEmpty);
      expect(config.resolveAnalysisDirectory().path, equals(tempDir.path));
      expect(
        config.duplicateCodeSimilarityThreshold,
        equals(FcheckConfig.defaultDuplicateCodeSimilarityThreshold),
      );
      expect(config.duplicateCodeMinTokens, equals(20));
      expect(config.duplicateCodeMinNonEmptyLines, equals(10));
      expect(FcheckConfig.defaultDuplicateCodeMinTokens, equals(20));
      expect(FcheckConfig.defaultDuplicateCodeMinNonEmptyLines, equals(10));
      expect(
        config.effectiveEnabledAnalyzers,
        equals(AnalyzerDomain.values.toSet()),
      );
    });

    test('reads input root and exclude patterns', () {
      File(p.join(tempDir.path, '.fcheck')).writeAsStringSync('''
input:
  root: app
  exclude:
    - "**/generated/**"
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      final analysisDir = config.resolveAnalysisDirectory();

      expect(
        p.normalize(analysisDir.path),
        equals(p.normalize(p.join(tempDir.path, 'app'))),
      );
      expect(config.excludePatterns, equals(['**/generated/**']));
      expect(
        config.mergeExcludePatterns(['**/*.g.dart']),
        equals(['**/generated/**', '**/*.g.dart']),
      );
    });

    test('supports analyzer opt-in mode', () {
      File(p.join(tempDir.path, '.fcheck')).writeAsStringSync('''
analyzers:
  default: off
  enabled:
    - magic_numbers
    - secrets
    - duplicate_code
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      expect(
        config.effectiveEnabledAnalyzers,
        equals({
          AnalyzerDomain.magicNumbers,
          AnalyzerDomain.secrets,
          AnalyzerDomain.duplicateCode,
        }),
      );
    });

    test('supports legacy ignores map', () {
      File(p.join(tempDir.path, '.fcheck')).writeAsStringSync('''
ignores:
  hardcoded_strings: true
  layers: true
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);
      expect(
        config.effectiveEnabledAnalyzers.contains(
          AnalyzerDomain.hardcodedStrings,
        ),
        isFalse,
      );
      expect(
        config.effectiveEnabledAnalyzers.contains(AnalyzerDomain.layers),
        isFalse,
      );
      expect(
        config.effectiveEnabledAnalyzers.contains(AnalyzerDomain.magicNumbers),
        isTrue,
      );
    });

    test('throws for unknown analyzer names', () {
      File(p.join(tempDir.path, '.fcheck')).writeAsStringSync('''
analyzers:
  disabled:
    - does_not_exist
''');

      expect(
        () => FcheckConfig.loadForInputDirectory(tempDir),
        throwsA(isA<FormatException>()),
      );
    });

    test('reads duplicate code options', () {
      File(p.join(tempDir.path, '.fcheck')).writeAsStringSync('''
analyzers:
  options:
    duplicate_code:
      similarity_threshold: 0.9
      min_tokens: 35
      min_non_empty_lines: 12
''');

      final config = FcheckConfig.loadForInputDirectory(tempDir);

      expect(config.duplicateCodeSimilarityThreshold, equals(0.9));
      expect(config.duplicateCodeMinTokens, equals(35));
      expect(config.duplicateCodeMinNonEmptyLines, equals(12));
    });
  });
}
