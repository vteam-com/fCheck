import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/input_output/path_style_utils.dart';
import 'package:path/path.dart' as p;

const int _relativeCurrentDirPrefixLength = 2;
const int _relativeParentDirPrefixLength = 3;

/// Checks whether a URI points to a Dart source file within project scope.
bool isProjectDartDependencyUri({
  required String uri,
  required String packageName,
}) {
  if (uri.startsWith('dart:')) {
    return false;
  }
  if (uri.startsWith('package:') && !uri.startsWith('package:$packageName/')) {
    return false;
  }
  if (uri.startsWith('package:$packageName/')) {
    return uri.endsWith('.dart');
  }
  return uri.endsWith('.dart');
}

/// Resolves a dependency URI to a project file path.
String resolveProjectDependencyUri({
  required String uri,
  required String currentFile,
  required String rootPath,
  required String packageName,
}) {
  final prefersBackslash =
      currentFile.contains('\\') || rootPath.contains('\\');

  String formatOutputPath(String path) {
    if (!prefersBackslash) {
      return path;
    }
    return path.replaceAll('/', '\\');
  }

  final normalizedCurrentFile = normalizeToPosixPath(currentFile);
  final normalizedRootPath = normalizeToPosixPath(rootPath);

  if (uri.startsWith('package:$packageName/')) {
    final packagePath = uri.substring('package:$packageName/'.length);
    return formatOutputPath(
      p.posix.join(normalizedRootPath, 'lib', packagePath),
    );
  }

  final currentDir = p.posix.dirname(normalizedCurrentFile);
  if (uri.startsWith('./')) {
    return formatOutputPath(
      p.posix.join(currentDir, uri.substring(_relativeCurrentDirPrefixLength)),
    );
  }
  if (uri.startsWith('../')) {
    var resolvedPath = currentDir;
    var remainingUri = uri;
    while (remainingUri.startsWith('../')) {
      resolvedPath = p.posix.dirname(resolvedPath);
      remainingUri = remainingUri.substring(_relativeParentDirPrefixLength);
    }
    return formatOutputPath(p.posix.join(resolvedPath, remainingUri));
  }

  return formatOutputPath(p.posix.join(currentDir, uri));
}

/// Adds a resolved dependency when [uri] is a project-scoped Dart URI.
void addResolvedProjectDartDependency({
  required String? uri,
  required String packageName,
  required String filePath,
  required String rootPath,
  required List<String> dependencies,
}) {
  if (uri == null ||
      !isProjectDartDependencyUri(uri: uri, packageName: packageName)) {
    return;
  }
  dependencies.add(
    resolveProjectDependencyUri(
      uri: uri,
      currentFile: filePath,
      rootPath: rootPath,
      packageName: packageName,
    ),
  );
}

/// Adds dependencies declared by a directive and conditional configurations.
void addDirectiveDartDependencies({
  required String? uri,
  required List<Configuration> configurations,
  required String packageName,
  required String filePath,
  required String rootPath,
  required List<String> dependencies,
}) {
  addResolvedProjectDartDependency(
    uri: uri,
    packageName: packageName,
    filePath: filePath,
    rootPath: rootPath,
    dependencies: dependencies,
  );

  if (configurations.isEmpty) {
    return;
  }

  for (final configuration in configurations) {
    addResolvedProjectDartDependency(
      uri: configuration.uri.stringValue,
      packageName: packageName,
      filePath: filePath,
      rootPath: rootPath,
      dependencies: dependencies,
    );
  }
}
