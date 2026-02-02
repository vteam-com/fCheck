// ignore: fcheck_one_class_per_file
// ignore: fcheck_secrets
import 'dart:io';
import 'dart:math';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_visitor.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_members.dart';
import 'package:fcheck/src/models/class_visitor.dart';
import 'package:fcheck/src/analyzers/layers/layers_visitor.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';

/// Delegate adapter for HardcodedStringAnalyzer
class HardcodedStringDelegate implements AnalyzerDelegate {
  /// Analyzes a file for hardcoded strings using the unified context.
  ///
  /// This method uses the pre-parsed AST to identify string literals that may
  /// be user-facing content that should be localized.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a list of [HardcodedStringIssue] objects representing
  /// potential hardcoded strings found in the file.
  @override
  List<HardcodedStringIssue> analyzeFileWithContext(
      AnalysisFileContext context) {
    final filePath = context.file.path;

    // Skip l10n generated files and files with ignore directive
    if (filePath.contains('lib/l10n/') ||
        filePath.contains('.g.dart') ||
        context.hasIgnoreDirective('hardcoded_strings')) {
      return [];
    }

    if (context.hasParseErrors || context.compilationUnit == null) {
      return [];
    }

    final visitor = HardcodedStringVisitor(
      filePath,
      context.content,
    );
    context.compilationUnit!.accept(visitor);

    return visitor.foundIssues;
  }
}

/// Delegate adapter for MagicNumberAnalyzer
class MagicNumberDelegate implements AnalyzerDelegate {
  /// Analyzes a file for magic numbers using the unified context.
  ///
  /// This method uses the pre-parsed AST to identify numeric literals that
  /// should be replaced with named constants.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a list of [MagicNumberIssue] objects representing
  /// magic number issues found in the file.
  @override
  List<MagicNumberIssue> analyzeFileWithContext(AnalysisFileContext context) {
    final filePath = context.file.path;

    if (_shouldSkipFile(filePath) ||
        context.hasIgnoreDirective('magic_numbers')) {
      return [];
    }

    if (context.hasParseErrors || context.compilationUnit == null) {
      return [];
    }

    final visitor = MagicNumberVisitor(filePath, context.content);
    context.compilationUnit!.accept(visitor);

    return visitor.foundIssues;
  }

  /// Checks if a file should be skipped during magic number analysis.
  ///
  /// Skips localization files and generated files that typically contain
  /// numeric values that are not magic numbers.
  ///
  /// [path] The file path to check.
  ///
  /// Returns true if the file should be skipped.
  bool _shouldSkipFile(String path) {
    return path.contains('lib/l10n/') || path.contains('.g.dart');
  }
}

/// Delegate adapter for SourceSortAnalyzer
class SourceSortDelegate implements AnalyzerDelegate {
  /// Whether to automatically fix sorting issues.
  final bool fix;

  /// Creates a new SourceSortDelegate.
  ///
  /// [fix] if true, automatically fixes sorting issues by writing sorted code back to files.
  SourceSortDelegate({this.fix = false});

  /// Analyzes a file for source sorting issues using the unified context.
  ///
  /// This method examines Flutter widget classes in the given file context and checks
  /// if their members are properly sorted according to Flutter conventions.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a list of [SourceSortIssue] objects representing any sorting
  /// issues found in Flutter classes within the file.
  @override
  List<SourceSortIssue> analyzeFileWithContext(AnalysisFileContext context) {
    final issues = <SourceSortIssue>[];

    if (context.hasParseErrors || context.compilationUnit == null) {
      return issues;
    }

    try {
      final classVisitor = ClassVisitor();
      context.compilationUnit!.accept(classVisitor);

      for (final ClassDeclaration classNode in classVisitor.targetClasses) {
        // ignore: deprecated_member_use
        final NodeList<ClassMember> members = classNode.members;
        if (members.isEmpty) {
          continue;
        }

        final sorter = MemberSorter(context.content, members);
        final sortedBody = sorter.getSortedBody();

        // Find the body boundaries
        // ignore: deprecated_member_use
        final classBodyStart = classNode.leftBracket.offset + 1;
        // ignore: deprecated_member_use
        final classBodyEnd = classNode.rightBracket.offset;
        final originalBody = context.content.substring(
          classBodyStart,
          classBodyEnd,
        );

        // Check if the body needs sorting
        if (_bodiesDiffer(sortedBody, originalBody)) {
          final lineNumber = context.getLineNumber(classNode.offset);
          final className = classNode.namePart.toString();

          if (fix) {
            // Write the sorted content back to the file
            final sortedContent = context.content.substring(0, classBodyStart) +
                sortedBody +
                context.content.substring(classBodyEnd);
            context.file.writeAsStringSync(sortedContent);
            print(
                '✅ Fixed sorting for class $className in ${context.file.path}');
          } else {
            // Report the issue
            issues.add(
              SourceSortIssue(
                filePath: context.file.path,
                className: className,
                lineNumber: lineNumber,
                description: 'Class members are not properly sorted',
              ),
            );
          }
        }
      }
    } catch (e) {
      // Skip files that can't be analyzed
    }

    return issues;
  }

  bool _bodiesDiffer(String sorted, String original) {
    final normalizedSorted = sorted.trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
    final normalizedOriginal = original.trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
    return normalizedSorted != normalizedOriginal;
  }
}

/// Delegate adapter for LayersAnalyzer
class LayersDelegate implements AnalyzerDelegate {
  /// The root directory of the project.
  final Directory rootDirectory;

  /// The package name for dependency resolution.
  final String packageName;

  /// Creates a new LayersDelegate.
  ///
  /// [rootDirectory] The project root directory.
  /// [packageName] The package name from pubspec.yaml.
  LayersDelegate(this.rootDirectory, this.packageName);

  /// Analyzes a file for layers dependencies using the unified context.
  ///
  /// This method extracts import/export dependencies and entry point status
  /// for layers architecture analysis.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a map containing 'dependencies' (list of file paths) and
  /// 'isEntryPoint' (boolean indicating if file has main() function).
  @override
  Map<String, dynamic> analyzeFileWithContext(AnalysisFileContext context) {
    if (context.hasIgnoreDirective('layers')) {
      return {
        'dependencies': <String>[],
        'isEntryPoint': false,
      };
    }

    if (context.hasParseErrors || context.compilationUnit == null) {
      return {
        'dependencies': <String>[],
        'isEntryPoint': false,
      };
    }

    final visitor = LayersVisitor(
      context.file.path,
      rootDirectory.path,
      packageName,
    );
    context.compilationUnit!.accept(visitor);

    return {
      'dependencies': visitor.dependencies,
      'isEntryPoint': visitor.hasMainFunction,
    };
  }
}

/// Delegate adapter for SecretAnalyzer
class SecretDelegate implements AnalyzerDelegate {
  /// Analyzes a file for secrets using the unified context.
  ///
  /// This method scans file content line by line for various types of secrets
  /// including API keys, tokens, private keys, and other sensitive information.
  ///
  /// [context] The pre-analyzed file context containing content and lines.
  ///
  /// Returns a list of [SecretIssue] objects representing secrets found in the file.
  @override
  List<SecretIssue> analyzeFileWithContext(AnalysisFileContext context) {
    // Check for ignore directive
    for (final line in context.lines.take(10)) {
      if (line.trim().contains('// ignore: fcheck_secrets')) {
        return [];
      }
    }

    final issues = <SecretIssue>[];

    for (int i = 0; i < context.lines.length; i++) {
      final lineFindings =
          _scanLine(context.lines[i], context.file.path, i + 1);
      issues.addAll(lineFindings);
    }

    return issues;
  }

  List<SecretIssue> _scanLine(String line, String filePath, int lineNumber) {
    final findings = <SecretIssue>[];

    // AWS Access Key
    if (_detectAwsAccessKey(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'aws_access_key',
        value: 'AWS Access Key detected',
      ));
    }

    // Generic Secret
    if (_detectGenericSecret(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'generic_secret',
        value: 'Generic secret detected',
      ));
    }

    // Bearer Token
    if (_detectBearerToken(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'bearer_token',
        value: 'Bearer token detected',
      ));
    }

    // Private Key
    if (_detectPrivateKey(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'private_key',
        value: 'Private key detected',
      ));
    }

    // Email PII
    if (_detectEmail(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'email_pii',
        value: 'Email address detected',
      ));
    }

    // Stripe Keys
    if (_detectStripeKey(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'stripe_key',
        value: 'Stripe key detected',
      ));
    }

    // GitHub PAT
    if (_detectGitHubPAT(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'github_pat',
        value: 'GitHub PAT detected',
      ));
    }

    // High Entropy Strings
    if (_detectHighEntropyString(line)) {
      findings.add(SecretIssue(
        filePath: filePath,
        lineNumber: lineNumber,
        secretType: 'high_entropy',
        value: 'High entropy string detected',
      ));
    }

    return findings;
  }

  bool _detectAwsAccessKey(String line) {
    final regex = RegExp(r'AKIA[0-9A-Z]{16}');
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (candidate.length == 20 && _calculateEntropy(candidate) > 3.5) {
        return true;
      }
    }
    return false;
  }

  bool _detectGenericSecret(String line) {
    final regex = RegExp(r'api[_-]?key|token|secret|password|private_key',
        caseSensitive: false);
    if (regex.hasMatch(line) && line.contains('=') && line.length > 20) {
      return _calculateEntropy(line) > 4.0;
    }
    return false;
  }

  bool _detectBearerToken(String line) {
    final regex = RegExp(r'Bearer\s+[a-zA-Z0-9_\-]{20,}', caseSensitive: false);
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (_calculateEntropy(candidate) > 3.8) {
        return true;
      }
    }
    return false;
  }

  bool _detectPrivateKey(String line) {
    final regex = RegExp(
        r'-----BEGIN\s+(RSA|EC|DSA|OPENSSH)\s+PRIVATE\s+KEY-----',
        caseSensitive: false);
    return regex.hasMatch(line);
  }

  bool _detectEmail(String line) {
    final regex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
        caseSensitive: false);
    return regex.hasMatch(line);
  }

  bool _detectStripeKey(String line) {
    final regex = RegExp(r'(sk_live_|pk_live_)[0-9a-zA-Z]{24}');
    return regex.hasMatch(line);
  }

  bool _detectGitHubPAT(String line) {
    final regex = RegExp(r'gh[p|s|o|u|l]_[0-9a-zA-Z]{36}|[gG]ithub_pat_');
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (candidate.length >= 40) {
        return true;
      }
    }
    return false;
  }

  bool _detectHighEntropyString(String line) {
    final regex = RegExp(r'[a-zA-Z0-9+/]{32,}');
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (_calculateEntropy(candidate) > 4.5) {
        return true;
      }
    }
    return false;
  }

  double _calculateEntropy(String str) {
    if (str.isEmpty) return 0.0;

    final counts = <String, int>{};
    for (final char in str.runes) {
      final charStr = String.fromCharCode(char);
      counts[charStr] = (counts[charStr] ?? 0) + 1;
    }

    double entropy = 0.0;
    final length = str.length;

    for (final count in counts.values) {
      final probability = count / length;
      entropy -= probability * (log(probability) / ln2);
    }

    return entropy;
  }
}
