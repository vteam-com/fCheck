import 'package:fcheck/src/analyzers/metrics/metrics_input.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_analyzer.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = MetricsAnalyzer();

  group('MetricsAnalyzer', () {
    test('returns perfect score for clean input', () {
      final result = analyzer.analyze(_buildInput());

      expect(result.complianceScore, equals(100));
      expect(result.suppressionPenaltyPoints, equals(0));
      expect(result.complianceFocusAreaKey, equals('none'));
      expect(result.complianceFocusAreaLabel, equals('None'));
    });

    test('selects magic numbers as focus area when score impact is highest',
        () {
      final result = analyzer.analyze(
        _buildInput(
          magicNumberIssues: [
            for (var i = 0; i < 10; i++)
              MagicNumberIssue(
                filePath: 'lib/file_$i.dart',
                lineNumber: i + 1,
                value: '${i + 1}',
              ),
          ],
        ),
      );

      expect(result.complianceScore, lessThan(100));
      expect(result.complianceFocusAreaKey, equals('magic_numbers'));
      expect(result.complianceFocusAreaLabel, equals('Magic numbers'));
      expect(
        result.complianceNextInvestment,
        equals('Replace magic numbers with named constants near domain logic.'),
      );
    });

    test('caps suppression penalty and prioritizes suppression hygiene', () {
      final result = analyzer.analyze(
        _buildInput(
          ignoreDirectivesCount: 20,
          customExcludedFilesCount: 8,
          hardcodedStringsAnalyzerEnabled: false,
          layersAnalyzerEnabled: false,
        ),
      );

      expect(result.suppressionPenaltyPoints, equals(25));
      expect(result.complianceFocusAreaKey, equals('suppression_hygiene'));
      expect(result.complianceFocusAreaLabel, equals('Suppression hygiene'));
      expect(result.complianceFocusAreaIssueCount, equals(30));
    });
  });
}

ProjectMetricsAnalysisInput _buildInput({
  int totalDartFiles = 10,
  int totalLinesOfCode = 1000,
  List<FileMetrics>? fileMetrics,
  List<MagicNumberIssue> magicNumberIssues = const [],
  int layersEdgeCount = 0,
  bool usesLocalization = true,
  int ignoreDirectivesCount = 0,
  int customExcludedFilesCount = 0,
  bool oneClassPerFileAnalyzerEnabled = true,
  bool hardcodedStringsAnalyzerEnabled = true,
  bool magicNumbersAnalyzerEnabled = true,
  bool sourceSortingAnalyzerEnabled = true,
  bool layersAnalyzerEnabled = true,
  bool secretsAnalyzerEnabled = true,
  bool deadCodeAnalyzerEnabled = true,
  bool duplicateCodeAnalyzerEnabled = true,
  bool documentationAnalyzerEnabled = true,
}) {
  final effectiveFileMetrics = fileMetrics ??
      List<FileMetrics>.generate(
        totalDartFiles,
        (index) => FileMetrics(
          path: 'lib/file_$index.dart',
          linesOfCode: (totalLinesOfCode / totalDartFiles).round(),
          commentLines: 10,
          classCount: 1,
          isStatefulWidget: false,
        ),
      );

  final disabledAnalyzersCount = [
    oneClassPerFileAnalyzerEnabled,
    hardcodedStringsAnalyzerEnabled,
    magicNumbersAnalyzerEnabled,
    sourceSortingAnalyzerEnabled,
    layersAnalyzerEnabled,
    secretsAnalyzerEnabled,
    deadCodeAnalyzerEnabled,
    duplicateCodeAnalyzerEnabled,
    documentationAnalyzerEnabled,
  ].where((enabled) => !enabled).length;

  return ProjectMetricsAnalysisInput(
    totalDartFiles: totalDartFiles,
    totalLinesOfCode: totalLinesOfCode,
    fileMetrics: effectiveFileMetrics,
    hardcodedStringIssues: const [],
    magicNumberIssues: magicNumberIssues,
    sourceSortIssues: const [],
    layersIssues: const [],
    secretIssues: const [],
    deadCodeIssues: const [],
    duplicateCodeIssues: const [],
    documentationIssues: const [],
    layersEdgeCount: layersEdgeCount,
    usesLocalization: usesLocalization,
    ignoreDirectivesCount: ignoreDirectivesCount,
    customExcludedFilesCount: customExcludedFilesCount,
    disabledAnalyzersCount: disabledAnalyzersCount,
    oneClassPerFileAnalyzerEnabled: oneClassPerFileAnalyzerEnabled,
    hardcodedStringsAnalyzerEnabled: hardcodedStringsAnalyzerEnabled,
    magicNumbersAnalyzerEnabled: magicNumbersAnalyzerEnabled,
    sourceSortingAnalyzerEnabled: sourceSortingAnalyzerEnabled,
    layersAnalyzerEnabled: layersAnalyzerEnabled,
    secretsAnalyzerEnabled: secretsAnalyzerEnabled,
    deadCodeAnalyzerEnabled: deadCodeAnalyzerEnabled,
    duplicateCodeAnalyzerEnabled: duplicateCodeAnalyzerEnabled,
    documentationAnalyzerEnabled: documentationAnalyzerEnabled,
  );
}
