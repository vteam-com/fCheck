import 'package:fcheck/src/analyzers/secrets/secret_scanner.dart';
import 'package:test/test.dart';

void main() {
  group('SecretScanner generic secret detection', () {
    final scanner = SecretScanner();

    test('does not flag identifier-only token usage', () {
      final content = '''
Future fetchData({required String idToken}) async {
  final String idToken = await ref.read(requireIdTokenProvider)();
}
static const Duration tokenRefresh = Duration(minutes: 2);
final requireIdTokenProvider = Provider((ref) => ref);
''';

      final issues = scanner.analyzeContent(
        filePath: 'test.dart',
        content: content,
      );
      final genericIssues =
          issues.where((issue) => issue.secretType == 'generic_secret');
      expect(genericIssues, isEmpty);
    });

    test('flags high-entropy token string literals', () {
      final content = '''
const apiToken = "abcdefghijklmnopqrstuvwxyzABCDEFG";
final headers = {"token": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi123456"};
''';

      final issues = scanner.analyzeContent(
        filePath: 'test.dart',
        content: content,
      );
      final genericIssues = issues
          .where((issue) => issue.secretType == 'generic_secret')
          .toList();
      expect(genericIssues.length, equals(2));
    });

    test('ignores short token string literals', () {
      final content = '''
const token = "short";
final password = "also-short";
''';

      final issues = scanner.analyzeContent(
        filePath: 'test.dart',
        content: content,
      );
      final genericIssues =
          issues.where((issue) => issue.secretType == 'generic_secret');
      expect(genericIssues, isEmpty);
    });
  });
}
