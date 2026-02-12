import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_scanner.dart';

/// Delegate adapter for secret scanning.
class SecretDelegate implements AnalyzerDelegate {
  final SecretScanner _scanner = SecretScanner();

  /// Analyzes a file for secrets using the unified context.
  ///
  /// This method scans file content line by line for various types of secrets
  /// including API keys, tokens, private keys, and other sensitive
  /// information.
  ///
  /// [context] The pre-analyzed file context containing content and lines.
  ///
  /// Returns a list of [SecretIssue] objects representing secrets found in the
  /// file.
  @override
  List<SecretIssue> analyzeFileWithContext(AnalysisFileContext context) {
    return _scanner.analyzeLines(
      filePath: context.file.path,
      lines: context.lines,
    );
  }
}
