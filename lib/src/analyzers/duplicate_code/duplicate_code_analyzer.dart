import 'dart:math' as math;

import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_file_data.dart';
import 'package:fcheck/src/analyzers/duplicate_code/duplicate_code_issue.dart';

/// Analyzer for duplicate code across normalized executable snippets.
class DuplicateCodeAnalyzer {
  /// Default similarity threshold used by the analyzer.
  static const double defaultSimilarityThreshold = 0.95;
  static const int _minimumSnippetsToCompare = 2;

  /// Creates a duplicate-code analyzer.
  DuplicateCodeAnalyzer({
    this.similarityThreshold = defaultSimilarityThreshold,
  });

  /// Minimum required similarity ratio (0.0 to 1.0).
  final double similarityThreshold;

  /// Returns duplicate-code issues for snippets that match above threshold.
  List<DuplicateCodeIssue> analyze(List<DuplicateCodeFileData> fileData) {
    if (fileData.isEmpty) {
      return <DuplicateCodeIssue>[];
    }

    final snippets = <DuplicateCodeSnippet>[];
    for (final data in fileData) {
      snippets.addAll(data.snippets);
    }

    if (snippets.length < _minimumSnippetsToCompare) {
      return <DuplicateCodeIssue>[];
    }

    snippets.sort((left, right) {
      final pathCompare = left.filePath.compareTo(right.filePath);
      if (pathCompare != 0) {
        return pathCompare;
      }
      final lineCompare = left.lineNumber.compareTo(right.lineNumber);
      if (lineCompare != 0) {
        return lineCompare;
      }
      return left.symbol.compareTo(right.symbol);
    });

    final issues = <DuplicateCodeIssue>[];

    for (var i = 0; i < snippets.length; i++) {
      final first = snippets[i];
      for (var j = i + 1; j < snippets.length; j++) {
        final second = snippets[j];
        if (first.parameterSignature != second.parameterSignature) {
          continue;
        }

        final minTokenCount = math.min(first.tokenCount, second.tokenCount);
        final maxTokenCount = math.max(first.tokenCount, second.tokenCount);

        if (maxTokenCount == 0) {
          continue;
        }

        if (minTokenCount / maxTokenCount < similarityThreshold) {
          continue;
        }

        final similarity = _calculateSimilarity(
          first.normalizedTokens,
          second.normalizedTokens,
        );

        if (similarity < similarityThreshold) {
          continue;
        }

        issues.add(
          DuplicateCodeIssue(
            firstFilePath: first.filePath,
            firstLineNumber: first.lineNumber,
            firstSymbol: first.symbol,
            secondFilePath: second.filePath,
            secondLineNumber: second.lineNumber,
            secondSymbol: second.symbol,
            similarity: similarity,
            lineCount: math.min(
              first.nonEmptyLineCount,
              second.nonEmptyLineCount,
            ),
          ),
        );
      }
    }

    issues.sort((left, right) {
      final similarityCompare = right.similarity.compareTo(left.similarity);
      if (similarityCompare != 0) {
        return similarityCompare;
      }

      final lineCountCompare = right.lineCount.compareTo(left.lineCount);
      if (lineCountCompare != 0) {
        return lineCountCompare;
      }

      final firstPathCompare =
          left.firstFilePath.compareTo(right.firstFilePath);
      if (firstPathCompare != 0) {
        return firstPathCompare;
      }

      final secondPathCompare =
          left.secondFilePath.compareTo(right.secondFilePath);
      if (secondPathCompare != 0) {
        return secondPathCompare;
      }

      final firstLineCompare =
          left.firstLineNumber.compareTo(right.firstLineNumber);
      if (firstLineCompare != 0) {
        return firstLineCompare;
      }

      final secondLineCompare =
          left.secondLineNumber.compareTo(right.secondLineNumber);
      if (secondLineCompare != 0) {
        return secondLineCompare;
      }

      final firstSymbolCompare = left.firstSymbol.compareTo(right.firstSymbol);
      if (firstSymbolCompare != 0) {
        return firstSymbolCompare;
      }

      return left.secondSymbol.compareTo(right.secondSymbol);
    });

    return issues;
  }

  double _calculateSimilarity(
    List<String> leftTokens,
    List<String> rightTokens,
  ) {
    final maxLength = math.max(leftTokens.length, rightTokens.length);
    if (maxLength == 0) {
      return 1;
    }

    final maxDistance =
        ((1 - similarityThreshold) * maxLength).floor().clamp(0, maxLength);

    final distance = _boundedLevenshtein(
      leftTokens,
      rightTokens,
      maxDistance,
    );

    if (distance > maxDistance) {
      return 0;
    }

    return 1 - (distance / maxLength);
  }

  int _boundedLevenshtein(
    List<String> left,
    List<String> right,
    int maxDistance,
  ) {
    if ((left.length - right.length).abs() > maxDistance) {
      return maxDistance + 1;
    }

    if (left.isEmpty) {
      return right.length;
    }

    if (right.isEmpty) {
      return left.length;
    }

    var source = left;
    var target = right;
    if (source.length > target.length) {
      source = right;
      target = left;
    }

    final sourceLength = source.length;
    final targetLength = target.length;
    var previous = List<int>.generate(targetLength + 1, (index) => index);

    for (var i = 1; i <= sourceLength; i++) {
      final current = List<int>.filled(targetLength + 1, maxDistance + 1);
      current[0] = i;

      final start = math.max(1, i - maxDistance);
      final end = math.min(targetLength, i + maxDistance);

      var rowMin = current[0];
      for (var j = start; j <= end; j++) {
        final replaceCost =
            previous[j - 1] + (source[i - 1] == target[j - 1] ? 0 : 1);
        final deleteCost = previous[j] + 1;
        final insertCost = current[j - 1] + 1;

        final nextValue =
            math.min(replaceCost, math.min(deleteCost, insertCost));
        current[j] = nextValue;
        rowMin = math.min(rowMin, nextValue);
      }

      if (rowMin > maxDistance) {
        return maxDistance + 1;
      }

      previous = current;
    }

    return previous[targetLength];
  }
}
