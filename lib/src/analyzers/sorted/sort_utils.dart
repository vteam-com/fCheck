/// Shared sorting helpers for source sorting analysis.
class SortUtils {
  /// Returns true when the normalized class bodies differ.
  static bool bodiesDiffer(String sorted, String original) {
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
