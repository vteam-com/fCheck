import 'package:fcheck/src/analyzers/metrics/metrics_input.dart';
import 'package:fcheck/src/analyzers/metrics/metrics_analyzer.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/models/code_size_thresholds.dart';
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

    test(
      'selects magic numbers as focus area when score impact is highest',
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
          equals(
            'Replace magic numbers with named constants near domain logic.',
          ),
        );
      },
    );

    test('applies deduction when code-size artifacts exceed thresholds', () {
      final result = analyzer.analyze(
        _buildInput(
          codeSizeArtifacts: const [
            CodeSizeArtifact(
              kind: CodeSizeArtifactKind.file,
              name: 'big.dart',
              filePath: 'lib/big.dart',
              linesOfCode: 120,
              startLine: 1,
              endLine: 120,
            ),
            CodeSizeArtifact(
              kind: CodeSizeArtifactKind.classDeclaration,
              name: 'HugeClass',
              filePath: 'lib/big.dart',
              linesOfCode: 90,
              startLine: 2,
              endLine: 100,
            ),
            CodeSizeArtifact(
              kind: CodeSizeArtifactKind.function,
              name: 'hugeFn',
              filePath: 'lib/big.dart',
              linesOfCode: 70,
              startLine: 105,
              endLine: 175,
            ),
            CodeSizeArtifact(
              kind: CodeSizeArtifactKind.method,
              name: 'hugeMethod',
              filePath: 'lib/big.dart',
              linesOfCode: 60,
              startLine: 20,
              endLine: 80,
              ownerName: 'HugeClass',
            ),
          ],
          codeSizeThresholds: const CodeSizeThresholds(
            maxFileLoc: 100,
            maxClassLoc: 80,
            maxFunctionLoc: 60,
            maxMethodLoc: 50,
          ),
        ),
      );

      expect(result.complianceScore, lessThan(100));
      expect(result.complianceFocusAreaKey, equals('code_size'));
    });

    test('caps suppression penalty and prioritizes checks bypassed', () {
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
      expect(result.complianceFocusAreaLabel, equals('Checks bypassed'));
      expect(result.complianceFocusAreaIssueCount, equals(30));
    });

    test('treats hardcoded strings as passive when localization is off', () {
      final result = analyzer.analyze(
        _buildInput(
          usesLocalization: false,
          hardcodedStringIssues: [
            HardcodedStringIssue(
              filePath: 'lib/main.dart',
              lineNumber: 2,
              value: 'hello',
            ),
          ],
        ),
      );

      final hardcodedScore = result.analyzerScores.firstWhere(
        (score) => score.key == 'hardcoded_strings',
      );
      expect(hardcodedScore.enabled, isFalse);
      expect(hardcodedScore.issueCount, equals(1));
      expect(hardcodedScore.scorePercent, equals(100));
      expect(result.complianceFocusAreaKey, isNot(equals('hardcoded_strings')));
    });
  });
}

ProjectMetricsAnalysisInput _buildInput({
  int totalDartFiles = 10,
  int totalLinesOfCode = 1000,
  List<FileMetrics>? fileMetrics,
  List<CodeSizeArtifact> codeSizeArtifacts = const [],
  CodeSizeThresholds codeSizeThresholds = const CodeSizeThresholds(),
  List<HardcodedStringIssue> hardcodedStringIssues = const [],
  List<MagicNumberIssue> magicNumberIssues = const [],
  int layersEdgeCount = 0,
  bool usesLocalization = true,
  int ignoreDirectivesCount = 0,
  int customExcludedFilesCount = 0,
  bool codeSizeAnalyzerEnabled = true,
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
  final effectiveFileMetrics =
      fileMetrics ??
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
    codeSizeAnalyzerEnabled,
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
    codeSizeArtifacts: codeSizeArtifacts,
    codeSizeThresholds: codeSizeThresholds,
    hardcodedStringIssues: hardcodedStringIssues,
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
    codeSizeAnalyzerEnabled: codeSizeAnalyzerEnabled,
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
