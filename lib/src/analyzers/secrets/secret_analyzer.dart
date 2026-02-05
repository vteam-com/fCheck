// ignore: fcheck_secrets
import 'dart:io';
import 'package:glob/glob.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_scanner.dart';

/// Advanced Secret Analyzer implementing SECRET.md rules
class SecretAnalyzer {
  final SecretScanner _scanner = SecretScanner();

  /// Analyze a directory for secrets
  List<SecretIssue> analyzeDirectory(
    Directory directory, {
    List<String> excludePatterns = const [],
  }) {
    final issues = <SecretIssue>[];

    final dartFiles = Directory(directory.path)
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .cast<File>()
        .where((file) =>
            file.path.endsWith('.dart') &&
            _shouldIncludeFile(file, excludePatterns))
        .toList();

    for (final file in dartFiles) {
      try {
        final content = file.readAsStringSync();
        final fileIssues = _analyzeFileContent(file.path, content);
        issues.addAll(fileIssues);
      } catch (e) {
        continue;
      }
    }

    return issues;
  }

  bool _shouldIncludeFile(File file, List<String> excludePatterns) {
    final relativePath = file.path.split(Platform.pathSeparator).join('/');

    for (final pattern in excludePatterns) {
      if (Glob(pattern).matches(relativePath)) {
        return false;
      }
    }

    return true;
  }

  List<SecretIssue> _analyzeFileContent(String filePath, String content) {
    return _scanner.analyzeContent(
      filePath: filePath,
      content: content,
    );
  }
}
