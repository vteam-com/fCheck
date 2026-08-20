import 'package:path/path.dart' as p;

/// Converts Windows-style separators to POSIX-style separators.
String normalizePathSeparators(String path) => path.replaceAll('\\', '/');

/// Normalizes a path and returns it with POSIX-style separators.
String normalizeToPosixPath(String path) =>
    p.posix.normalize(normalizePathSeparators(path));
