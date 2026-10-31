import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/shared/dependency_uri_utils.dart';
import 'package:fcheck/src/fcheck_test_summary.dart';
import 'package:fcheck/src/fcheck_test_visitor.dart';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:fcheck/src/input_output/path_style_utils.dart';
import 'package:fcheck/src/models/file_metrics.dart';
import 'package:path/path.dart' as p;

const Set<String> _testDirectoryNames = {'test', 'integration_test'};

/// Counts test cases and collects project imports from the test sources
/// under [projectDir] in one pass.
///
/// Only imports found in [analyzedPaths] are kept.
({int testCaseCount, Set<String> importedPaths}) analyzeTestFiles({
  required Directory projectDir,
  required String rootPath,
  required String packageName,
  required Set<String> analyzedPaths,
}) {
  var totalTestCases = 0;
  final importedPaths = <String>{};

  for (final file in _listTestDartFiles(projectDir)) {
    try {
      final content = file.readAsStringSync();
      final parseResult = parseString(
        content: content,
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      final context = AnalysisFileContext(
        file: file,
        content: content,
        parseResult: parseResult,
        lines: content.split('\n'),
        compilationUnit: parseResult.unit,
        hasParseErrors: parseResult.errors.isNotEmpty,
      );
      final counter = TestCaseVisitor();
      parseResult.unit.accept(counter);
      totalTestCases += counter.testCaseCount;
      importedPaths.addAll(
        collectProjectDependencies(
          context,
          rootPath: rootPath,
          packageName: packageName,
        ).where(analyzedPaths.contains),
      );
    } catch (_) {
      // Ignore unreadable/un-parseable test files and continue.
    }
  }

  return (testCaseCount: totalTestCases, importedPaths: importedPaths);
}

/// Resolves which analyzed files are statically exercised by test imports.
///
/// The analysis starts from project files imported by test files, then walks
/// the dependency graph transitively to estimate consumed files, LOC,
/// classes, methods, and top-level functions.
TestConsumptionSummary analyzeTestConsumption({
  required Map<String, List<String>> dependencyGraph,
  required List<FileMetrics> fileMetrics,
  required String analysisRootPath,
  required Set<String> importedPathsSet,
}) {
  if (dependencyGraph.isEmpty || importedPathsSet.isEmpty) {
    return const TestConsumptionSummary.empty();
  }

  final analyzedPaths = dependencyGraph.keys.toSet();
  final queue = Queue<String>()..addAll(importedPathsSet);
  final consumedPathsSet = <String>{};
  while (queue.isNotEmpty) {
    final currentPath = queue.removeFirst();
    if (!consumedPathsSet.add(currentPath)) {
      continue;
    }
    for (final dependency in dependencyGraph[currentPath] ?? const <String>[]) {
      if (!analyzedPaths.contains(dependency) ||
          consumedPathsSet.contains(dependency)) {
        continue;
      }
      queue.add(dependency);
    }
  }

  final metricsByPath = <String, FileMetrics>{
    for (final metric in fileMetrics) p.normalize(metric.path): metric,
  };
  var linesOfCode = 0;
  var classCount = 0;
  var methodCount = 0;
  var topLevelFunctionCount = 0;
  for (final path in consumedPathsSet) {
    final metric = metricsByPath[path];
    if (metric == null) {
      continue;
    }
    linesOfCode += metric.linesOfCode;
    classCount += metric.classCount;
    methodCount += metric.methodCount;
    topLevelFunctionCount += metric.topLevelFunctionCount;
  }

  final normalizedAnalysisRoot = p.normalize(
    Directory(analysisRootPath).absolute.path,
  );
  List<String> toSortedDisplayPaths(Set<String> paths) =>
      paths
          .map(
            (path) => toRelativePathForDisplay(
              path,
              normalizedRootPath: normalizedAnalysisRoot,
            ),
          )
          .toList(growable: false)
        ..sort();

  return TestConsumptionSummary(
    importedPaths: toSortedDisplayPaths(importedPathsSet),
    consumedPaths: toSortedDisplayPaths(consumedPathsSet),
    linesOfCode: linesOfCode,
    classCount: classCount,
    methodCount: methodCount,
    topLevelFunctionCount: topLevelFunctionCount,
  );
}

/// Lists Dart files located under canonical test directories.
List<File> _listTestDartFiles(Directory dir) {
  final files = <File>[];
  for (final entity in FileUtils.listProjectEntities(dir)) {
    if (entity is! File || p.extension(entity.path) != '.dart') {
      continue;
    }
    final relativePath = p.relative(entity.path, from: dir.path);
    final pathParts = p.split(relativePath);
    final isHidden = pathParts.any((part) => part.startsWith('.'));
    if (isHidden) {
      continue;
    }
    final isTestFile = pathParts.any(_testDirectoryNames.contains);
    if (isTestFile) {
      files.add(entity);
    }
  }
  return files;
}
