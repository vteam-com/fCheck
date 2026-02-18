import 'package:fcheck/src/analyzers/metrics/metrics_input.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectMetricsAnalysisInput', () {
    test('creates instance with all required fields', () {
      final input = ProjectMetricsAnalysisInput(
        totalDartFiles: 10,
        totalLinesOfCode: 500,
        fileMetrics: [],
        codeSizeArtifacts: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        secretIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
        documentationIssues: [],
        layersEdgeCount: 5,
        usesLocalization: true,
        ignoreDirectivesCount: 3,
        customExcludedFilesCount: 1,
        disabledAnalyzersCount: 2,
        oneClassPerFileAnalyzerEnabled: true,
        hardcodedStringsAnalyzerEnabled: true,
        magicNumbersAnalyzerEnabled: true,
        sourceSortingAnalyzerEnabled: true,
        layersAnalyzerEnabled: true,
        secretsAnalyzerEnabled: true,
        deadCodeAnalyzerEnabled: true,
        duplicateCodeAnalyzerEnabled: true,
        documentationAnalyzerEnabled: true,
      );

      expect(input.totalDartFiles, equals(10));
      expect(input.totalLinesOfCode, equals(500));
      expect(input.usesLocalization, isTrue);
      expect(input.ignoreDirectivesCount, equals(3));
      expect(input.disabledAnalyzersCount, equals(2));
      expect(input.oneClassPerFileAnalyzerEnabled, isTrue);
      expect(input.hardcodedStringsAnalyzerEnabled, isTrue);
      expect(input.magicNumbersAnalyzerEnabled, isTrue);
      expect(input.sourceSortingAnalyzerEnabled, isTrue);
      expect(input.layersAnalyzerEnabled, isTrue);
      expect(input.secretsAnalyzerEnabled, isTrue);
      expect(input.deadCodeAnalyzerEnabled, isTrue);
      expect(input.duplicateCodeAnalyzerEnabled, isTrue);
      expect(input.documentationAnalyzerEnabled, isTrue);
    });

    test('creates instance with disabled analyzers', () {
      final input = ProjectMetricsAnalysisInput(
        totalDartFiles: 5,
        totalLinesOfCode: 200,
        fileMetrics: [],
        codeSizeArtifacts: [],
        hardcodedStringIssues: [],
        magicNumberIssues: [],
        sourceSortIssues: [],
        layersIssues: [],
        secretIssues: [],
        deadCodeIssues: [],
        duplicateCodeIssues: [],
        documentationIssues: [],
        layersEdgeCount: 0,
        usesLocalization: false,
        ignoreDirectivesCount: 0,
        customExcludedFilesCount: 0,
        disabledAnalyzersCount: 5,
        oneClassPerFileAnalyzerEnabled: false,
        hardcodedStringsAnalyzerEnabled: false,
        magicNumbersAnalyzerEnabled: false,
        sourceSortingAnalyzerEnabled: false,
        layersAnalyzerEnabled: false,
        secretsAnalyzerEnabled: false,
        deadCodeAnalyzerEnabled: false,
        duplicateCodeAnalyzerEnabled: false,
        documentationAnalyzerEnabled: false,
      );

      expect(input.disabledAnalyzersCount, equals(5));
      expect(input.oneClassPerFileAnalyzerEnabled, isFalse);
      expect(input.hardcodedStringsAnalyzerEnabled, isFalse);
    });
  });
}
