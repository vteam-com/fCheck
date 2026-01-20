/// Hardcoded string detection for Flutter/Dart projects.
///
/// This module analyzes Dart source files to identify hardcoded strings
/// that may need to be localized or moved to constants. It intelligently
/// skips strings that are legitimately hardcoded (imports, annotations,
/// const declarations, etc.).
import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Represents a hardcoded string finding.
class HardcodedStringIssue {
  /// The file path where the hardcoded string was found.
  final String filePath;

  /// The line number where the hardcoded string appears.
  final int lineNumber;

  /// The hardcoded string value.
  final String value;

  /// Creates a new hardcoded string issue.
  HardcodedStringIssue({
    required this.filePath,
    required this.lineNumber,
    required this.value,
  });

  @override
  String toString() => '$filePath:$lineNumber: "$value"';
}

/// Analyzer for detecting hardcoded strings in Dart files.
class HardcodedStringAnalyzer {
  /// Analyzes a single Dart file for hardcoded strings.
  ///
  /// [file] The Dart file to analyze.
  ///
  /// Returns a list of [HardcodedStringIssue] objects representing
  /// potential hardcoded strings found in the file.
  List<HardcodedStringIssue> analyzeFile(File file) {
    final String filePath = file.path;

    // Skip l10n generated files
    if (filePath.contains('lib/l10n/') || filePath.contains('.g.dart')) {
      return [];
    }

    final String content = file.readAsStringSync();

    final ParseStringResult result = parseString(
      content: content,
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    // Skip files with parse errors
    if (result.errors.isNotEmpty) {
      return [];
    }

    final CompilationUnit compilationUnit = result.unit;
    final HardcodedStringVisitor visitor = HardcodedStringVisitor(
      filePath,
      content,
    );
    compilationUnit.accept(visitor);

    return visitor.foundIssues;
  }

  /// Analyzes all Dart files in a directory for hardcoded strings.
  ///
  /// [directory] The root directory to scan.
  ///
  /// Returns a list of all [HardcodedStringIssue] objects found.
  List<HardcodedStringIssue> analyzeDirectory(Directory directory) {
    final List<HardcodedStringIssue> allIssues = [];

    final List<File> dartFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    for (final File file in dartFiles) {
      allIssues.addAll(analyzeFile(file));
    }

    return allIssues;
  }
}

class HardcodedStringVisitor extends GeneralizingAstVisitor<void> {
  HardcodedStringVisitor(this.filePath, this.content);

  final String filePath;
  final String content;
  final List<HardcodedStringIssue> foundIssues = <HardcodedStringIssue>[];

  @override
  void visitSimpleStringLiteral(final SimpleStringLiteral node) {
    // Skip empty strings
    if (node.value.isEmpty) {
      return;
    }

    // Skip strings that are in import/part/library directives
    if (_isInDirective(node)) {
      return;
    }

    // Skip strings in annotations
    if (_isInAnnotation(node)) {
      return;
    }

    // Skip strings that are keys in Map literals (common for const maps)
    if (_isMapKey(node)) {
      return;
    }

    // Skip strings in const declarations
    if (_isInConstDeclaration(node)) {
      return;
    }

    // Skip strings in l10n calls (basic detection)
    if (_isInL10nCall(node)) {
      return;
    }

    // Skip strings in RegExp calls
    if (_isInRegExpCall(node)) {
      return;
    }

    // Skip strings in Key constructors
    if (_isInKey(node)) {
      return;
    }

    // Skip strings used as index in collections/maps
    if (_isIndex(node)) {
      return;
    }

    // Get line number
    final int lineNumber = _getLineNumber(node.offset);

    foundIssues.add(HardcodedStringIssue(
      filePath: filePath,
      lineNumber: lineNumber,
      value: node.value,
    ));
  }

  bool _isInDirective(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ImportDirective ||
          current is ExportDirective ||
          current is PartDirective ||
          current is PartOfDirective ||
          current is LibraryDirective) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInAnnotation(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Annotation) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isMapKey(final AstNode node) {
    final AstNode? parent = node.parent;
    if (parent is MapLiteralEntry) {
      return parent.key == node;
    }
    return false;
  }

  bool _isInConstDeclaration(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is VariableDeclaration) {
        final VariableDeclaration varDecl = current;
        if (varDecl.parent is VariableDeclarationList) {
          final VariableDeclarationList varList =
              varDecl.parent as VariableDeclarationList;
          if (varList.isConst) {
            return true;
          }
        }
      } else if (current is FieldDeclaration && current.fields.isConst) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInL10nCall(final AstNode node) {
    // Basic detection for AppLocalizations calls
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final MethodInvocation invocation = current;
        final Expression? target = invocation.target;
        if (target != null && target.toString().contains('AppLocalizations')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInRegExpCall(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final MethodInvocation invocation = current;
        if (invocation.methodName.name == 'RegExp') {
          return true;
        }
      } else if (current is InstanceCreationExpression) {
        final InstanceCreationExpression creation = current;
        if (creation.constructorName.name?.name == 'RegExp') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInKey(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final InstanceCreationExpression creation = current;
        final String? constructorName = creation.constructorName.name?.name;
        if (constructorName == 'Key' ||
            constructorName == 'ValueKey' ||
            constructorName == 'ObjectKey' ||
            constructorName == null) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  bool _isIndex(final AstNode node) {
    final AstNode? parent = node.parent;
    if (parent is IndexExpression) {
      return parent.index == node;
    }
    return false;
  }

  int _getLineNumber(final int offset) {
    final List<String> lines = content.substring(0, offset).split('\n');
    return lines.length;
  }
}
