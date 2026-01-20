// Utility functions for the app

/// A simple utility class that provides helper methods
class AppUtils {
  /// Converts a string to title case
  static String toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  /// Calculates the sum of a list of numbers
  static int sum(List<int> numbers) {
    return numbers.fold(0, (a, b) => a + b);
  }
}
