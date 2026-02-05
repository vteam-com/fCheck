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
  /// Creates a delegate for hardcoded string analysis.
  ///
  /// [focus] controls which string literals are considered (Flutter widgets,
  /// Dart print output, or general).
  HardcodedStringDelegate({this.focus = HardcodedStringFocus.general});

  /// Focus mode used by the hardcoded string visitor.
  final HardcodedStringFocus focus;

  static const int _maxShortWidgetStringLength = 2;
  static const int _minQuotedLength = 2;
  static const int _dollarSignOffset = 1;
  static const int _asciiDigitStart = 48;
  static const int _asciiDigitEnd = 57;
  static const int _asciiUpperStart = 65;
  static const int _asciiUpperEnd = 90;
  static const int _asciiLowerStart = 97;
  static const int _asciiLowerEnd = 122;

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

    final issues = <HardcodedStringIssue>[];

    if (focus == HardcodedStringFocus.flutterWidgets) {
      issues.addAll(_scanWidgetTextLiterals(context));
    }

    if (context.compilationUnit == null) {
      return issues;
    }

    final visitor = HardcodedStringVisitor(
      filePath,
      context.content,
      focus: focus,
    );
    context.compilationUnit!.accept(visitor);

    if (issues.isEmpty) {
      return visitor.foundIssues;
    }

    final seen = <String>{
      for (final issue in issues) '${issue.lineNumber}:${issue.value}',
    };
    for (final issue in visitor.foundIssues) {
      final key = '${issue.lineNumber}:${issue.value}';
      if (seen.add(key)) {
        issues.add(issue);
      }
    }

    return issues;
  }

  List<HardcodedStringIssue> _scanWidgetTextLiterals(
    AnalysisFileContext context,
  ) {
    final issues = <HardcodedStringIssue>[];
    final regex = RegExp(
      r'''\bText\s*\(\s*(['"])(.*?)\1''',
      dotAll: true,
    );

    for (final match in regex.allMatches(context.content)) {
      final value = match.group(_minQuotedLength) ?? '';
      if (value.isEmpty || value.length <= _maxShortWidgetStringLength) {
        continue;
      }

      if (_isInterpolationOnlyString(value)) {
        continue;
      }

      if (_isTechnicalString(value)) {
        continue;
      }

      final matchText = match.group(0) ?? '';
      final valueOffsetInMatch = matchText.indexOf(value);
      final literalOffset =
          match.start + (valueOffsetInMatch < 0 ? 0 : valueOffsetInMatch);
      final lineNumber = context.getLineNumber(literalOffset);
      if (lineNumber <= 0 || lineNumber > context.lines.length) {
        continue;
      }

      final line = context.lines[lineNumber - 1];
      if (line.trimLeft().startsWith('//')) {
        continue;
      }

      if (_hasWidgetLintIgnoreComment(line) ||
          line.contains('// ignore: fcheck_hardcoded_strings')) {
        continue;
      }

      if (lineNumber > 1) {
        final previousLine = context.lines[lineNumber - _minQuotedLength];
        if (_hasWidgetLintIgnoreComment(previousLine)) {
          continue;
        }
      }

      issues.add(
        HardcodedStringIssue(
          filePath: context.file.path,
          lineNumber: lineNumber,
          value: value,
        ),
      );
    }

    return issues;
  }

  bool _hasWidgetLintIgnoreComment(String line) {
    final ignorePatterns = [
      RegExp(r'//\s*ignore:\s*avoid_hardcoded_strings_in_widgets'),
      RegExp(r'//\s*ignore_for_file:\s*avoid_hardcoded_strings_in_widgets'),
      RegExp(r'//\s*ignore:\s*hardcoded.string', caseSensitive: false),
      RegExp(r'//\s*hardcoded.ok', caseSensitive: false),
    ];

    return ignorePatterns.any((pattern) => pattern.hasMatch(line));
  }

  bool _isInterpolationOnlyString(String value) {
    final String withoutInterpolations = _removeInterpolations(value);
    return !_containsMeaningfulText(withoutInterpolations);
  }

  String _removeInterpolations(String source) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < source.length) {
      final char = source[i];
      if (char == r'$' && (i == 0 || source[i - 1] != r'\')) {
        if (i + _dollarSignOffset < source.length &&
            source[i + _dollarSignOffset] == '{') {
          i += _minQuotedLength;
          var depth = 1;
          while (i < source.length && depth > 0) {
            final current = source[i];
            if (current == '{') {
              depth++;
            } else if (current == '}') {
              depth--;
            }
            i++;
          }
          continue;
        }

        i += _dollarSignOffset;
        while (i < source.length && _isIdentifierChar(source[i])) {
          i++;
        }
        continue;
      }

      buffer.write(char);
      i++;
    }

    return buffer.toString();
  }

  bool _isIdentifierChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= _asciiDigitStart && code <= _asciiDigitEnd) || // 0-9
        (code >= _asciiUpperStart && code <= _asciiUpperEnd) || // A-Z
        (code >= _asciiLowerStart && code <= _asciiLowerEnd) || // a-z
        char == '_';
  }

  bool _containsMeaningfulText(String text) {
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      final isAlphaNumeric =
          (code >= _asciiDigitStart && code <= _asciiDigitEnd) ||
              (code >= _asciiUpperStart && code <= _asciiUpperEnd) ||
              (code >= _asciiLowerStart && code <= _asciiLowerEnd);
      if (isAlphaNumeric) {
        return true;
      }
    }
    return false;
  }

  bool _isTechnicalString(String value) {
    final technicalPatterns = [
      RegExp(r'^\w+://'),
      RegExp(r'^[\w\-\.]+@[\w\-\.]+\.\w+'),
      RegExp(r'^#[0-9A-Fa-f]{3,8}'),
      RegExp(r'^\d+(\.\d+)?[a-zA-Z]*'),
      RegExp(r'^[A-Z][A-Z0-9]*_[A-Z0-9_]*'),
      RegExp(r'^[a-z]+_[a-z_]+'),
      RegExp(r'^/[\w/\-\.]*'),
      RegExp(r'^\w+\.\w+'),
      RegExp(r'^[\w\-]+\.[\w]+'),
      RegExp(r'^[a-zA-Z0-9]*[_\-0-9]+[a-zA-Z0-9_\-]*'),
    ];

    return technicalPatterns.any((pattern) => pattern.hasMatch(value.trim()));
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
  static const int _ignoreDirectiveScanLines = 10;
  static const int _awsAccessKeyLength = 20;
  static const double _awsEntropyThreshold = 3.5;
  static const int _genericSecretLineMinLength = 20;
  static const double _genericSecretEntropyThreshold = 4.0;
  static const int _bearerTokenMinLength = 20;
  static const double _bearerTokenEntropyThreshold = 3.8;
  static const int _githubPatMinLength = 40;
  static const double _highEntropyThreshold = 4.5;

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
    for (final line in context.lines.take(_ignoreDirectiveScanLines)) {
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
      if (candidate.length == _awsAccessKeyLength &&
          _calculateEntropy(candidate) > _awsEntropyThreshold) {
        return true;
      }
    }
    return false;
  }

  bool _detectGenericSecret(String line) {
    final regex = RegExp(r'api[_-]?key|token|secret|password|private_key',
        caseSensitive: false);
    if (regex.hasMatch(line) &&
        line.contains('=') &&
        line.length > _genericSecretLineMinLength) {
      return _calculateEntropy(line) > _genericSecretEntropyThreshold;
    }
    return false;
  }

  bool _detectBearerToken(String line) {
    final regex = RegExp(
      'Bearer\\s+[a-zA-Z0-9_\\-]{$_bearerTokenMinLength,}',
      caseSensitive: false,
    );
    final matches = regex.allMatches(line);
    for (final match in matches) {
      final candidate = match.group(0) ?? '';
      if (_calculateEntropy(candidate) > _bearerTokenEntropyThreshold) {
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
      if (candidate.length >= _githubPatMinLength) {
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
      if (_calculateEntropy(candidate) > _highEntropyThreshold) {
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
