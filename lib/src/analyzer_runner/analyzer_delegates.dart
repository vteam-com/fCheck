// ignore: fcheck_one_class_per_file
// ignore: fcheck_secrets
import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_utils.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_visitor.dart';
import 'package:fcheck/src/analyzers/magic_numbers/magic_number_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_members.dart';
import 'package:fcheck/src/analyzers/sorted/sort_utils.dart';
import 'package:fcheck/src/models/class_visitor.dart';
import 'package:fcheck/src/models/ignore_config.dart';
import 'package:fcheck/src/analyzers/layers/layers_visitor.dart';
import 'package:fcheck/src/analyzers/secrets/secret_issue.dart';
import 'package:fcheck/src/analyzers/secrets/secret_scanner.dart';
import 'package:fcheck/src/input_output/output.dart';

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
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreDirectiveForHardcodedStrings,
        ) ||
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreForFileDirectiveForHardcodedStrings,
        )) {
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
      final value = match.group(HardcodedStringUtils.minQuotedLength) ?? '';
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
          line.contains(IgnoreConfig.ignoreDirectiveForHardcodedStrings)) {
        continue;
      }

      if (lineNumber > 1) {
        final previousLine =
            context.lines[lineNumber - HardcodedStringUtils.minQuotedLength];
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
    final String withoutInterpolations =
        HardcodedStringUtils.removeInterpolations(value);
    return !HardcodedStringUtils.containsMeaningfulText(withoutInterpolations);
  }

  bool _isTechnicalString(String value) {
    return HardcodedStringUtils.isTechnicalString(value);
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
        context.hasIgnoreForFileDirective(
          IgnoreConfig.ignoreDirectiveForMagicNumbers,
        )) {
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

/// Delegate adapter for source sorting
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
        if (SortUtils.bodiesDiffer(sortedBody, originalBody)) {
          final lineNumber = context.getLineNumber(classNode.offset);
          final className = classNode.namePart.toString();

          if (fix) {
            // Write the sorted content back to the file
            final sortedContent = context.content.substring(0, classBodyStart) +
                sortedBody +
                context.content.substring(classBodyEnd);
            context.file.writeAsStringSync(sortedContent);
            print(
                '${okTag()} Fixed sorting for class $className in ${context.file.path}');
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
    if (context.hasIgnoreForFileDirective(
      IgnoreConfig.ignoreDirectiveForLayers,
    )) {
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
  final SecretScanner _scanner = SecretScanner();

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
    return _scanner.analyzeLines(
      filePath: context.file.path,
      lines: context.lines,
    );
  }
}
