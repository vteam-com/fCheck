import 'package:fcheck/src/metrics/file_metrics.dart';
import 'package:test/test.dart';

void main() {
  group('FileMetrics', () {
    test('should create FileMetrics instance correctly', () {
      final metrics = FileMetrics(
        path: 'lib/example.dart',
        linesOfCode: 50,
        commentLines: 10,
        classCount: 1,
        isStatefulWidget: false,
      );

      expect(metrics.path, equals('lib/example.dart'));
      expect(metrics.linesOfCode, equals(50));
      expect(metrics.commentLines, equals(10));
      expect(metrics.classCount, equals(1));
      expect(metrics.isStatefulWidget, isFalse);
    });

    test('should be compliant with one class per file rule for regular file',
        () {
      final metrics = FileMetrics(
        path: 'lib/example.dart',
        linesOfCode: 50,
        commentLines: 10,
        classCount: 1,
        isStatefulWidget: false,
      );

      expect(metrics.isOneClassPerFileCompliant, isTrue);
    });

    test(
        'should be non-compliant with one class per file rule for regular file with multiple classes',
        () {
      final metrics = FileMetrics(
        path: 'lib/example.dart',
        linesOfCode: 50,
        commentLines: 10,
        classCount: 3,
        isStatefulWidget: false,
      );

      expect(metrics.isOneClassPerFileCompliant, isFalse);
    });

    test('should be compliant for StatefulWidget with 2 classes', () {
      final metrics = FileMetrics(
        path: 'lib/home_page.dart',
        linesOfCode: 100,
        commentLines: 20,
        classCount: 2,
        isStatefulWidget: true,
      );

      expect(metrics.isOneClassPerFileCompliant, isTrue);
    });

    test('should be non-compliant for StatefulWidget with more than 2 classes',
        () {
      final metrics = FileMetrics(
        path: 'lib/home_page.dart',
        linesOfCode: 100,
        commentLines: 20,
        classCount: 4,
        isStatefulWidget: true,
      );

      expect(metrics.isOneClassPerFileCompliant, isFalse);
    });

    test('should be compliant when ignore directive is set', () {
      final metrics = FileMetrics(
        path: 'lib/legacy.dart',
        linesOfCode: 120,
        commentLines: 5,
        classCount: 5,
        isStatefulWidget: false,
        ignoreOneClassPerFile: true,
      );

      expect(metrics.isOneClassPerFileCompliant, isTrue);
    });

    test('should handle private classes correctly (only count public classes)',
        () {
      // This test demonstrates that classCount should only include public classes
      // The actual counting logic is in the analyzer, but we test the compliance rule
      final metrics = FileMetrics(
        path: 'lib/example.dart',
        linesOfCode: 100,
        commentLines: 15,
        classCount: 1, // Only 1 public class, even if there are private classes
        isStatefulWidget: false,
      );

      expect(metrics.isOneClassPerFileCompliant, isTrue);
    });
  });
}
