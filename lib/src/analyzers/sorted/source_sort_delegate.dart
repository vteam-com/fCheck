import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/shared/generated_file_utils.dart';
import 'package:fcheck/src/analyzers/sorted/sort_issue.dart';
import 'package:fcheck/src/analyzers/sorted/sort_members.dart';
import 'package:fcheck/src/analyzers/sorted/sort_utils.dart';
import 'package:fcheck/src/models/class_visitor.dart';
import 'package:path/path.dart' as p;

const int _minimumImportsToSort = 2;
const int _importGroupDart = 0;
const int _importGroupPackage = 1;
const int _importGroupOtherAbsolute = 2;
const int _importGroupRelative = 3;

class _ImportEntry {
  final ImportDirective directive;
  final String uri;
  final String sourceText;

  _ImportEntry({
    required this.directive,
    required this.uri,
    required this.sourceText,
  });
}

/// Delegate adapter for source sorting.
class SourceSortDelegate implements AnalyzerDelegate {
  /// Whether to automatically fix sorting issues.
  final bool fix;

  /// The current package name used for `lib/` relative-to-package rewriting.
  final String packageName;

  /// Creates a new SourceSortDelegate.
  ///
  /// [fix] if true, automatically fixes sorting issues by writing sorted code
  /// back to files.
  SourceSortDelegate({this.fix = false, this.packageName = ''});

  /// Analyzes a file for source sorting issues using the unified context.
  ///
  /// This method examines Flutter widget classes in the given file context and
  /// checks if their members are properly sorted according to Flutter
  /// conventions.
  ///
  /// [context] The pre-analyzed file context containing AST and content.
  ///
  /// Returns a list of [SourceSortIssue] objects representing any sorting
  /// issues found in Flutter classes within the file.
  @override
  List<SourceSortIssue> analyzeFileWithContext(AnalysisFileContext context) {
    final issues = <SourceSortIssue>[];

    if (isGeneratedDartFilePath(context.file.path) ||
        context.hasParseErrors ||
        context.compilationUnit == null) {
      return issues;
    }

    try {
      final classVisitor = ClassVisitor();
      context.compilationUnit!.accept(classVisitor);

      for (final ClassDeclaration classNode in classVisitor.targetClasses) {
        final classBody = classNode.body;
        if (classBody is! BlockClassBody) {
          continue;
        }
        final NodeList<ClassMember> members = classBody.members;
        if (members.isEmpty) {
          continue;
        }

        final sorter = MemberSorter(context.content, members);
        final sortedBody = sorter.getSortedBody();

        // Find the body boundaries.
        final classBodyStart = classBody.leftBracket.offset + 1;
        final classBodyEnd = classBody.rightBracket.offset;
        final originalBody = context.content.substring(
          classBodyStart,
          classBodyEnd,
        );

        // Check if the body needs sorting.
        if (SortUtils.bodiesDiffer(sortedBody, originalBody)) {
          if (fix) {
            // Write the sorted content back to the file.
            final sortedContent =
                context.content.substring(0, classBodyStart) +
                sortedBody +
                context.content.substring(classBodyEnd);
            context.file.writeAsStringSync(sortedContent);
          } else {
            // Report the issue.
            issues.add(
              SourceSortIssue(
                filePath: context.file.path,
                className: classNode.namePart.toString(),
                lineNumber: context.getLineNumber(classNode.offset),
                description: 'Class members are not properly sorted',
              ),
            );
          }
        }
      }

      if (fix) {
        _sortImportsInFile(context.file.path);
      }
    } catch (_) {
      // Skip files that can't be analyzed.
    }

    return issues;
  }

  /// Reorders file import directives to match analyzer directive ordering.
  ///
  /// Imports are grouped by URI kind (`dart:*`, `package:*`, other absolute
  /// URIs, relative paths) and sorted alphabetically inside each group.
  void _sortImportsInFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return;
    }

    final originalContent = file.readAsStringSync();
    final parseResult = parseString(
      content: originalContent,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    if (parseResult.errors.isNotEmpty) {
      return;
    }

    final imports = parseResult.unit.directives.whereType<ImportDirective>();
    final originalImports = imports.toList(growable: false);
    if (originalImports.length < _minimumImportsToSort) {
      return;
    }

    final originalEntries = originalImports
        .map((directive) {
          final uri = directive.uri.stringValue ?? '';
          final normalizedUri = _normalizeImportUri(uri, filePath);
          return _ImportEntry(
            directive: directive,
            uri: normalizedUri,
            sourceText: _rewriteDirectiveSource(directive, normalizedUri),
          );
        })
        .toList(growable: false);

    final sortedEntries = [...originalEntries]
      ..sort((a, b) {
        final uriA = a.uri;
        final uriB = b.uri;
        final groupComparison = _importGroupPriority(
          uriA,
        ).compareTo(_importGroupPriority(uriB));
        if (groupComparison != 0) {
          return groupComparison;
        }
        return _compareDirectiveUris(uriA, uriB);
      });

    final sortedImportText = _buildImportSection(sortedEntries);
    final start = originalEntries.first.directive.offset;
    final end = originalEntries.last.directive.end;
    final originalImportText = originalContent
        .substring(start, end)
        .trimRight();

    var changed = false;
    for (var i = 0; i < originalEntries.length; i++) {
      if (originalEntries[i].directive != sortedEntries[i].directive ||
          originalEntries[i].sourceText != sortedEntries[i].sourceText) {
        changed = true;
        break;
      }
    }
    if (!changed && originalImportText == sortedImportText) {
      return;
    }

    final updatedContent =
        originalContent.substring(0, start) +
        sortedImportText +
        originalContent.substring(end);
    file.writeAsStringSync(updatedContent);
  }

  /// Builds the replacement import section text.
  ///
  /// A single blank line is inserted between distinct import groups.
  String _buildImportSection(List<_ImportEntry> sortedEntries) {
    final buffer = StringBuffer();
    int? previousGroup;

    for (final entry in sortedEntries) {
      final uri = entry.uri;
      final group = _importGroupPriority(uri);
      if (previousGroup != null && previousGroup != group) {
        buffer.writeln();
      }
      buffer.writeln(entry.sourceText);
      previousGroup = group;
    }

    return buffer.toString().trimRight();
  }

  /// Returns the import group priority used for import ordering.
  int _importGroupPriority(String uri) {
    if (uri.startsWith('dart:')) {
      return _importGroupDart;
    }
    if (uri.startsWith('package:')) {
      return _importGroupPackage;
    }
    if (uri.contains(':')) {
      return _importGroupOtherAbsolute;
    }
    return _importGroupRelative;
  }

  /// Compares import URIs using the same package/path ordering used by linter.
  int _compareDirectiveUris(String a, String b) {
    final indexA = a.indexOf('/');
    final indexB = b.indexOf('/');
    if (indexA == -1 || indexB == -1) {
      return a.compareTo(b);
    }
    final packageComparison = a
        .substring(0, indexA)
        .compareTo(b.substring(0, indexB));
    if (packageComparison != 0) {
      return packageComparison;
    }
    return a.substring(indexA + 1).compareTo(b.substring(indexB + 1));
  }

  /// Rewrites relative import URIs to package URIs when they resolve under
  /// the current project's `lib/` directory.
  ///
  /// Non-relative URIs and paths outside `lib/` are returned unchanged.
  String _normalizeImportUri(String uri, String filePath) {
    if (uri.contains(':') || packageName.isEmpty || uri.isEmpty) {
      return uri;
    }
    final normalizedFilePath = p.normalize(filePath);
    final sourceDir = p.dirname(normalizedFilePath);
    final targetAbsolutePath = p.normalize(p.join(sourceDir, uri));
    final projectRoot = _findProjectRoot(normalizedFilePath);
    if (projectRoot == null) {
      return uri;
    }

    final libRoot = p.join(projectRoot, 'lib');
    final targetInsideLib =
        p.isWithin(libRoot, targetAbsolutePath) ||
        targetAbsolutePath == libRoot;
    if (!targetInsideLib) {
      return uri;
    }

    final packagePath = p.relative(targetAbsolutePath, from: libRoot);
    final normalizedPackagePath = packagePath.replaceAll(r'\', '/');
    if (normalizedPackagePath.isEmpty ||
        normalizedPackagePath.startsWith('../')) {
      return uri;
    }

    return 'package:$packageName/$normalizedPackagePath';
  }

  /// Finds the nearest project root by walking parent directories until a
  /// `pubspec.yaml` is found.
  ///
  /// Returns null when no project root marker exists.
  String? _findProjectRoot(String filePath) {
    var current = Directory(p.dirname(filePath));
    while (true) {
      final pubspecFile = File(p.join(current.path, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        return current.path;
      }
      final parent = current.parent;
      if (parent.path == current.path) {
        return null;
      }
      current = parent;
    }
  }

  /// Returns import directive source with the URI literal replaced by [uri]
  /// while preserving quote style and directive suffixes.
  String _rewriteDirectiveSource(ImportDirective directive, String uri) {
    final originalUri = directive.uri.stringValue;
    if (originalUri == null || originalUri == uri) {
      return directive.toSource();
    }

    final source = directive.toSource();
    final updated = source.replaceFirstMapped(
      RegExp("(['\"])${RegExp.escape(originalUri)}\\1"),
      (match) {
        final quote = match.group(1) ?? "'";
        return '$quote$uri$quote';
      },
    );
    return updated;
  }
}
