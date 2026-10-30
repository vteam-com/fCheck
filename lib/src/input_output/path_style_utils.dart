import 'package:path/path.dart' as p;

/// Converts Windows-style separators to POSIX-style separators.
String normalizePathSeparators(String path) => path.replaceAll('\\', '/');

/// Normalizes a path and returns it with POSIX-style separators.
String normalizeToPosixPath(String path) =>
    p.posix.normalize(normalizePathSeparators(path));

/// Returns [path] rebased to [normalizedRootPath] for user-facing output.
String toRelativePathForDisplay(
  String path, {
  required String normalizedRootPath,
}) {
  if (path.isEmpty) {
    return path;
  }

  final absolutePath = p.isAbsolute(path)
      ? p.normalize(path)
      : p.normalize(p.join(normalizedRootPath, path));
  return normalizePathSeparators(
    p.relative(absolutePath, from: normalizedRootPath),
  );
}
