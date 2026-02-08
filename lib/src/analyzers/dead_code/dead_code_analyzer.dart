import 'dart:io';
import 'package:fcheck/src/analyzers/dead_code/dead_code_file_data.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/models/project_type.dart';
import 'package:path/path.dart' as p;

/// Analyzer for detecting dead code across the project.
class DeadCodeAnalyzer {
  /// Creates a dead code analyzer for the given project.
  DeadCodeAnalyzer({
    required this.projectRoot,
    required this.packageName,
    required this.projectType,
  });

  /// Root directory of the analyzed project.
  final Directory projectRoot;

  /// Package name from pubspec.yaml.
  final String packageName;

  /// Project type used to determine entry points and public API rules.
  final ProjectType projectType;

  /// Computes dead code issues using collected per-file data.
  List<DeadCodeIssue> analyze(List<DeadCodeFileData> fileData) {
    if (fileData.isEmpty) {
      return <DeadCodeIssue>[];
    }

    final fileDataByPath = <String, DeadCodeFileData>{
      for (final data in fileData) data.filePath: data,
    };

    final dependencyGraph = <String, List<String>>{};
    for (final data in fileData) {
      final filteredDeps = data.dependencies
          .where((dep) => fileDataByPath.containsKey(dep))
          .toList();
      dependencyGraph[data.filePath] = filteredDeps;
    }

    final entryPoints = _resolveEntryPoints(fileDataByPath);
    final reachable = _findReachableFiles(dependencyGraph, entryPoints);

    final usedIdentifiers = <String>{};
    final useReachableOnly = entryPoints.isNotEmpty;
    for (final data in fileData) {
      if (!useReachableOnly || reachable.contains(data.filePath)) {
        usedIdentifiers.addAll(data.usedIdentifiers);
      }
    }

    final issues = <DeadCodeIssue>[];

    if (entryPoints.isNotEmpty) {
      for (final path in fileDataByPath.keys) {
        if (!reachable.contains(path)) {
          issues.add(
            DeadCodeIssue(
              type: DeadCodeIssueType.deadFile,
              filePath: path,
              name: p.basename(path),
            ),
          );
        }
      }
    }

    final bool hasMainEntryPoint = fileData.any((data) => data.hasMain == true);
    final bool treatPublicApiAsUsed =
        !hasMainEntryPoint && projectType == ProjectType.dart;
    final String libRoot = p.join(projectRoot.path, 'lib');

    for (final data in fileData) {
      final bool isPublicLibFile = data.filePath.startsWith(libRoot) &&
          !data.filePath.contains('${p.separator}src${p.separator}');

      for (final symbol in data.classes) {
        if (treatPublicApiAsUsed && isPublicLibFile) {
          continue;
        }
        if (!usedIdentifiers.contains(symbol.name)) {
          issues.add(
            DeadCodeIssue(
              type: DeadCodeIssueType.deadClass,
              filePath: data.filePath,
              lineNumber: symbol.lineNumber,
              name: symbol.name,
            ),
          );
        }
      }

      for (final symbol in data.functions) {
        if (symbol.name == 'main') {
          continue;
        }
        if (treatPublicApiAsUsed && isPublicLibFile) {
          continue;
        }
        if (!usedIdentifiers.contains(symbol.name)) {
          issues.add(
            DeadCodeIssue(
              type: DeadCodeIssueType.deadFunction,
              filePath: data.filePath,
              lineNumber: symbol.lineNumber,
              name: symbol.name,
            ),
          );
        }
      }

      issues.addAll(data.unusedVariableIssues);
    }

    return issues;
  }

  Set<String> _resolveEntryPoints(
    Map<String, DeadCodeFileData> fileDataByPath,
  ) {
    final entryPoints = <String>{};
    for (final entry in fileDataByPath.entries) {
      if (entry.value.hasMain) {
        entryPoints.add(entry.key);
      }
    }

    if (entryPoints.isNotEmpty) {
      return entryPoints;
    }

    final libRoot = p.join(projectRoot.path, 'lib');
    if (projectType == ProjectType.dart) {
      final packageEntry = p.join(libRoot, '$packageName.dart');
      if (fileDataByPath.containsKey(packageEntry)) {
        entryPoints.add(packageEntry);
      }

      for (final path in fileDataByPath.keys) {
        if (path.startsWith(libRoot) && p.dirname(path) == libRoot) {
          entryPoints.add(path);
        }
      }
    }

    return entryPoints;
  }

  Set<String> _findReachableFiles(
    Map<String, List<String>> dependencyGraph,
    Set<String> entryPoints,
  ) {
    final reachable = <String>{};
    final stack = <String>[...entryPoints];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!reachable.add(current)) {
        continue;
      }
      final deps = dependencyGraph[current] ?? <String>[];
      for (final dep in deps) {
        if (!reachable.contains(dep)) {
          stack.add(dep);
        }
      }
    }

    return reachable;
  }
}
