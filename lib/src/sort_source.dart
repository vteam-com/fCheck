import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'utils.dart';

/// Represents an issue found with source code sorting
class SourceSortIssue {
  SourceSortIssue({
    required this.filePath,
    required this.className,
    required this.lineNumber,
    required this.description,
  });

  final String filePath;
  final String className;
  final int lineNumber;
  final String description;
}

/// Analyzes Dart files for proper source code member ordering in Flutter classes
class SourceSortAnalyzer {
  /// Analyzes a single file for source sorting issues
  List<SourceSortIssue> analyzeFile(File file) {
    final List<SourceSortIssue> issues = <SourceSortIssue>[];

    try {
      final String content = file.readAsStringSync();

      final ParseStringResult result = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      if (result.errors.isNotEmpty) {
        // Skip files with parse errors
        return issues;
      }

      final CompilationUnit compilationUnit = result.unit;
      final ClassVisitor classVisitor = ClassVisitor();
      compilationUnit.accept(classVisitor);

      for (final ClassDeclaration classNode in classVisitor.targetClasses) {
        // In analyzer AST, class members are accessed directly
        // ignore: deprecated_member_use
        final NodeList<ClassMember> members = classNode.members;
        if (members.isEmpty) {
          continue;
        }

        final MemberSorter sorter = MemberSorter(content, members);
        final String sortedBody = sorter.getSortedBody();

        // Find the body boundaries
        // ignore: deprecated_member_use
        final int classBodyStart = classNode.leftBracket.offset + 1;
        // ignore: deprecated_member_use
        final int classBodyEnd = classNode.rightBracket.offset;
        final String originalBody = content.substring(
          classBodyStart,
          classBodyEnd,
        );

        // Check if the body needs sorting
        if (_bodiesDiffer(sortedBody, originalBody)) {
          final int lineNumber = _getLineNumber(content, classNode.offset);
          issues.add(SourceSortIssue(
            filePath: file.path,
            className: classNode.namePart.toString(),
            lineNumber: lineNumber,
            description: 'Class members are not properly sorted',
          ));
        }
      }
    } catch (e) {
      // Skip files that can't be analyzed
    }

    return issues;
  }

  /// Analyzes a directory for source sorting issues
  List<SourceSortIssue> analyzeDirectory(Directory directory) {
    final List<SourceSortIssue> allIssues = <SourceSortIssue>[];

    final List<File> dartFiles = FileUtils.listDartFiles(directory);
    for (final File file in dartFiles) {
      allIssues.addAll(analyzeFile(file));
    }

    return allIssues;
  }

  /// Check if two class bodies are different (ignoring whitespace)
  bool _bodiesDiffer(String sorted, String original) {
    final String normalizedSorted =
        sorted.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String normalizedOriginal =
        original.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalizedSorted != normalizedOriginal;
  }

  /// Get the line number for a given offset in the content
  int _getLineNumber(String content, int offset) {
    int lineNumber = 1;
    for (int i = 0; i < offset && i < content.length; i++) {
      if (content[i] == '\n') {
        lineNumber++;
      }
    }
    return lineNumber;
  }
}

/// Finds classes that we want to sort: StatelessWidget, StatefulWidget, or
/// State<...> classes (the typical Flutter patterns).
class ClassVisitor extends GeneralizingAstVisitor<void> {
  final List<ClassDeclaration> targetClasses = <ClassDeclaration>[];

  @override
  void visitClassDeclaration(final ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final String superName = extendsClause.superclass.toString();
      // Match StatelessWidget, StatefulWidget, or State (including generics: State<MyWidget>)
      if (superName == 'StatelessWidget' ||
          superName == 'StatefulWidget' ||
          superName == 'State' ||
          superName.startsWith('State<')) {
        targetClasses.add(node);
      }
    }
    super.visitClassDeclaration(node);
  }
}

/// Sorts members inside a class body so that:
/// 1) non-method members (fields, constructors, etc.) remain first in their original order
/// 2) all public methods (alphabetical) come next
/// 3) all private methods (alphabetical) come last
class MemberSorter {
  MemberSorter(this._content, this._members);
  final String _content;
  final NodeList<ClassMember> _members;

  String getSortedBody() {
    final NodeList<ClassMember> members = _members;
    if (members.isEmpty) {
      return '';
    }

    final List<String> otherMembers = <String>[];
    final List<_SortableMethod> lifecycleMethods = <_SortableMethod>[];
    final List<_SortableMethod> publicMethods = <_SortableMethod>[];
    final List<_SortableMethod> privateMethods = <_SortableMethod>[];

    final Set<String> lifecycleMethodNames = <String>{
      'initState',
      'dispose',
      'didChangeDependencies',
      'didUpdateWidget',
      'build',
    };

    // Map from field name to list of member sources (field + associated getters/setters)
    final Map<String, List<String>> fieldGroups = <String, List<String>>{};
    // Keep track of which members have been grouped (to skip later)
    final Set<ClassMember> groupedMembers = <ClassMember>{};

    // First, group FieldDeclarations and their associated PropertyAccessorDeclarations
    for (final ClassMember member in members) {
      if (member is FieldDeclaration) {
        // For each variable declared in the field
        for (final VariableDeclaration variable in member.fields.variables) {
          final String name = variable.name.lexeme;
          final List<String> groupSources = <String>[];
          groupSources.add(_getSource(member));
          fieldGroups[name] = groupSources;
          groupedMembers.add(member);
        }
      }
    }

    // Now associate PropertyAccessorDeclarations (getters/setters) with their fields if possible
    for (final ClassMember member in members) {
      if (member is MethodDeclaration && (member.isGetter || member.isSetter)) {
        final String name = member.name.lexeme;
        if (fieldGroups.containsKey(name)) {
          fieldGroups[name]!.add(_getSource(member));
          groupedMembers.add(member);
        }
      }
    }

    // Add non-field, non-method members (e.g., constructors) in original order at the top
    for (final ClassMember member in members) {
      if (!groupedMembers.contains(member) && member is! MethodDeclaration) {
        otherMembers.add(_getSource(member));
      }
    }

    // Collect fields and their grouped accessors into a list and sort alphabetically
    final List<_SortableField> sortedFields = <_SortableField>[];
    for (final String fieldName in fieldGroups.keys) {
      sortedFields.add(_SortableField(fieldName, fieldGroups[fieldName]!));
    }
    sortedFields.sort(
      (final _SortableField a, final _SortableField b) =>
          a.name.compareTo(b.name),
    );

    // Add sorted fields to otherMembers
    for (final _SortableField field in sortedFields) {
      otherMembers.addAll(field.sources);
    }

    // Now process standalone methods only (exclude getters/setters which were grouped)
    for (final ClassMember member in members) {
      if (member is MethodDeclaration && !groupedMembers.contains(member)) {
        final String name = member.name.lexeme;
        if (lifecycleMethodNames.contains(name)) {
          lifecycleMethods.add(_SortableMethod(name, _getSource(member)));
        } else if (name.startsWith('_')) {
          privateMethods.add(_SortableMethod(name, _getSource(member)));
        } else {
          publicMethods.add(_SortableMethod(name, _getSource(member)));
        }
      }
    }

    // Sort lifecycle methods in fixed order (preserve exact order as in lifecycleOrder)
    final List<String> lifecycleOrder = <String>[
      'initState',
      'dispose',
      'didChangeDependencies',
      'didUpdateWidget',
      'build',
    ];

    final Map<String, int> lifecycleOrderMap = <String, int>{
      for (int i = 0; i < lifecycleOrder.length; i++) lifecycleOrder[i]: i,
    };

    lifecycleMethods.sort(
      (final _SortableMethod a, final _SortableMethod b) =>
          (lifecycleOrderMap[a.name] ?? 999).compareTo(
        lifecycleOrderMap[b.name] ?? 999,
      ),
    );
    publicMethods.sort(
      (final _SortableMethod a, final _SortableMethod b) =>
          a.name.compareTo(b.name),
    );

    privateMethods.sort(
      (final _SortableMethod a, final _SortableMethod b) =>
          a.name.compareTo(b.name),
    );

    final List<String> parts = <String>[];
    if (otherMembers.isNotEmpty) {
      parts.addAll(otherMembers.map((final String s) => s.trimRight()));
    }
    if (lifecycleMethods.isNotEmpty) {
      if (parts.isNotEmpty) {
        parts.add('');
      }
      parts.addAll(
        lifecycleMethods.map((final _SortableMethod m) => m.source.trimRight()),
      );
    }
    if (publicMethods.isNotEmpty) {
      if (parts.isNotEmpty) {
        parts.add('');
      }
      parts.addAll(
        publicMethods.map((final _SortableMethod m) => m.source.trimRight()),
      );
    }
    if (privateMethods.isNotEmpty) {
      if (parts.isNotEmpty) {
        parts.add('');
      }
      parts.addAll(
        privateMethods.map((final _SortableMethod m) => m.source.trimRight()),
      );
    }

    final String result = parts.join('\n\n');
    return result.isEmpty ? '' : '\n$result\n';
  }

  String _getSource(final AstNode node) =>
      _content.substring(node.offset, node.end);
}

class _SortableMethod {
  _SortableMethod(this.name, this.source);
  final String name;
  final String source;
}

class _SortableField {
  _SortableField(this.name, this.sources);
  final String name;
  final List<String> sources;
}
