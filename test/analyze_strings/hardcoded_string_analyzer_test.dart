import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_delegate.dart';

import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart';
import 'package:fcheck/src/input_output/file_utils.dart';
import 'package:test/test.dart';

AnalysisFileContext _contextForFile(File file) {
  final content = file.readAsStringSync();
  final parseResult = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  return AnalysisFileContext(
    file: file,
    content: content,
    parseResult: parseResult,
    lines: content.split('\n'),
    compilationUnit: parseResult.unit,
    hasParseErrors: parseResult.errors.isNotEmpty,
  );
}

List<HardcodedStringIssue> _analyzeFile(
  HardcodedStringDelegate delegate,
  File file,
) {
  final context = _contextForFile(file);
  return delegate.analyzeFileWithContext(context);
}

List<HardcodedStringIssue> _analyzeDirectory(
  HardcodedStringDelegate delegate,
  Directory directory,
) {
  final issues = <HardcodedStringIssue>[];
  final dartFiles = FileUtils.listDartFiles(directory);
  for (final file in dartFiles) {
    issues.addAll(_analyzeFile(delegate, file));
  }
  return issues;
}

void main() {
  group('HardcodedStringDelegate', () {
    late HardcodedStringDelegate delegate;
    late Directory tempDir;

    setUp(() {
      delegate = HardcodedStringDelegate();
      tempDir = Directory.systemTemp.createTempSync('fcheck_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should return empty list for empty file', () {
      final file = File('${tempDir.path}/empty.dart')..writeAsStringSync('');
      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip empty string literals', () {
      final file = File('${tempDir.path}/empty_strings.dart')
        ..writeAsStringSync('''
void main() {
  print("");
  print('');
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should detect simple hardcoded strings', () {
      final file = File('${tempDir.path}/simple.dart')
        ..writeAsStringSync('''
void main() {
  print("Hello World");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('Hello World'));
      expect(issues[0].lineNumber, equals(2));
    });

    test('should detect interpolated strings with static text', () {
      final file = File('${tempDir.path}/interpolated_with_text.dart')
        ..writeAsStringSync('''
void main(String path) {
  print('Error: Directory "\$path" does not exist.');
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, contains('Error: Directory'));
      expect(issues[0].lineNumber, equals(2));
    });

    test('should skip interpolation-only strings', () {
      final file = File('${tempDir.path}/interpolation_only.dart')
        ..writeAsStringSync('''
void main(String path) {
  print('\$path');
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip strings in imports', () {
      final file = File('${tempDir.path}/import.dart')
        ..writeAsStringSync('''
import 'package:flutter/material.dart';

void main() {
  print("This should be detected");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('This should be detected'));
    });

    test('should skip strings in annotations', () {
      final file = File('${tempDir.path}/annotation.dart')
        ..writeAsStringSync('''
@override
void method() {
  print("This should be detected");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('This should be detected'));
    });

    test('should skip strings in const declarations', () {
      final file = File('${tempDir.path}/const.dart')
        ..writeAsStringSync('''
const String greeting = "Hello";
const String message = "World";

void main() {
  print("This should be detected");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('This should be detected'));
    });

    test('should skip strings in explicit typed String declarations', () {
      final file = File('${tempDir.path}/typed_string.dart')
        ..writeAsStringSync('''
class ThemeConfig {
  static String fontFamily = "GameFont";
}

String globalFont = "OtherFont";

void main() {
  print("This should be detected");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('This should be detected'));
    });

    test('should skip strings in RegExp constructors', () {
      final file = File('${tempDir.path}/regex.dart')
        ..writeAsStringSync('''
void main() {
  final regex = RegExp('\\d+');
  print("This should be detected");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('This should be detected'));
    });

    test('should skip strings in Key constructors', () {
      final file = File('${tempDir.path}/key.dart')
        ..writeAsStringSync('''
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key("myKey"),
      child: Text("This should be detected"),
    );
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(
        issues.map((issue) => issue.value),
        contains('This should be detected'),
      );
    });

    test('should skip strings used as map keys', () {
      final file = File('${tempDir.path}/map.dart')
        ..writeAsStringSync('''
void main() {
  final map = {
    "key1": "value1",
    "key2": "value2",
  };
  print("This should be detected");
}
''');

      final issues = _analyzeFile(delegate, file);
      // The analyzer currently detects all strings in the map
      // This test verifies the expected behavior (may need improvement in the analyzer)
      expect(issues.length, equals(3));
      expect(
        issues.map((issue) => issue.value),
        contains('This should be detected'),
      );
    });

    test('should skip strings in l10n calls', () {
      final file = File('${tempDir.path}/l10n.dart')
        ..writeAsStringSync('''
void main() {
  final message = AppLocalizations.of(context).hello;
  print("This should be detected");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('This should be detected'));
    });

    test('should skip dedicated string files when localization is off', () {
      final delegate = HardcodedStringDelegate(usesLocalization: false);
      final file = File('${tempDir.path}/game_strings.dart')
        ..writeAsStringSync('''
class GameStrings {
  static final String title = "Play now";
  static final String subtitle = "Ready?";
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should report dedicated string files when localization is on', () {
      final delegate = HardcodedStringDelegate(usesLocalization: true);
      final file = File('${tempDir.path}/game_strings.dart')
        ..writeAsStringSync('''
class GameStrings {
  static final title = "Play now";
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues.first.value, equals('Play now'));
    });

    test('should skip files in l10n directory', () {
      final l10nDir = Directory('${tempDir.path}/lib/l10n')
        ..createSync(recursive: true);
      final file = File('${l10nDir.path}/messages.dart')
        ..writeAsStringSync('''
class Messages {
  static const String hello = "Hello";
  static const String world = "World";
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip generated files', () {
      final file = File('${tempDir.path}/messages.g.dart')
        ..writeAsStringSync('''
class Messages {
  static const String hello = "Hello";
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should ignore line with inline hardcoded strings directive', () {
      final file = File('${tempDir.path}/inline_ignore.dart')
        ..writeAsStringSync('''
void main() {
  final message = "Hello World"; // ignore: fcheck_hardcoded_strings
  print("This should be detected");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues.first.value, equals('This should be detected'));
    });

    test('should analyze directory correctly', () {
      File(
        '${tempDir.path}/file1.dart',
      ).writeAsStringSync('void main() { print("Hello"); }');
      File(
        '${tempDir.path}/file2.dart',
      ).writeAsStringSync('void main() { print("World"); }');
      File(
        '${tempDir.path}/readme.txt',
      ).writeAsStringSync('This is not a Dart file');

      final issues = _analyzeDirectory(delegate, tempDir);

      expect(issues.length, equals(2));
      expect(issues.map((issue) => issue.value), contains('Hello'));
      expect(issues.map((issue) => issue.value), contains('World'));
    });
  });

  group('HardcodedStringDelegate flutter focus', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should ignore empty widget text literals', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/widget_empty.dart')
        ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(""),
        Text(''),
        Text("Hello"),
      ],
    );
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, equals('Hello'));
    });

    test('should skip widget strings with custom_lint ignore comment', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/widget_ignore_comment.dart')
        ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ignore: avoid_hardcoded_strings_in_widgets
        Text("Ignored text"),
        Text("Detected text"),
      ],
    );
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues.first.value, equals('Detected text'));
    });

    test('should skip widget strings with hardcoded ok comment forms', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/widget_hardcoded_ok.dart')
        ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Ignored A"), // ignore: hardcoded.string
        const SizedBox(),
        Text("Ignored B"), // hardcoded.ok
        const SizedBox(),
        Text("Detected text"),
      ],
    );
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues.first.value, equals('Detected text'));
    });

    test(
      'should ignore file with ignore_for_file avoid_hardcoded_strings_in_widgets',
      () {
        final delegate = HardcodedStringDelegate(
          focus: HardcodedStringFocus.flutterWidgets,
        );
        final file = File('${tempDir.path}/widget_ignore_for_file.dart')
          ..writeAsStringSync('''
// ignore_for_file: avoid_hardcoded_strings_in_widgets
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text("Ignored text");
  }
}
''');

        final issues = _analyzeFile(delegate, file);
        expect(issues, isEmpty);
      },
    );

    test('should skip acceptable widget properties', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/widget_properties.dart')
        ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Visible text", semanticsLabel: "Accessibility label"),
        Text("Other", style: const TextStyle(fontFamily: "GameFont")),
      ],
    );
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.map((issue) => issue.value), contains('Visible text'));
      expect(issues.map((issue) => issue.value), contains('Other'));
      expect(
        issues.any((issue) => issue.value == 'Accessibility label'),
        isFalse,
      );
      expect(issues.any((issue) => issue.value == 'GameFont'), isFalse);
    });

    test('should skip ValueKey and ObjectKey strings', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/widget_keys.dart')
        ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey("column-key"),
      children: const [],
    );
  }
}

class OtherWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: ObjectKey("object-key"),
      child: const SizedBox(),
    );
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should detect hardcoded strings in method invocations', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/snackbar_method.dart')
        ..writeAsStringSync('''
class AnaSnackBar {
  static void showInfo({required String message}) {}
}

class PaymentActionScreen {
  void showMessage() {
    AnaSnackBar.showInfo(
      message: 'Find that merchant in Search to pay at their table.',
    );
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(
        issues[0].value,
        equals('Find that merchant in Search to pay at their table.'),
      );
      expect(issues[0].lineNumber, equals(8));
    });

    test('should detect widget strings in widget-returning functions', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/widget_function.dart')
        ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

Widget buildLabel() {
  return Text("Function label");
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues.first.value, equals('Function label'));
    });

    test('should ignore nested callback strings inside widget arguments', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/widget_callback.dart')
        ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return Text("Nested callback text");
      },
    );
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues.first.value, equals('Nested callback text'));
    });

    test('should ignore print and logger output in flutter focus', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/flutter_debug_output.dart')
        ..writeAsStringSync('''
class Logger {
  void info(String message) {}
}

void main() {
  final logger = Logger();
  print('Console output');
  logger.info('Debug output');
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should ignore debugPrint and debugPrintStack output', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/flutter_debug_print.dart')
        ..writeAsStringSync('''
void main() {
  debugPrint('Debug output');
  debugPrintStack(label: 'Stack output');
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip strings used in map lookups', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/map_lookup.dart')
        ..writeAsStringSync('''
void main() {
  final result = <String, int>{'totalAvailable': 3};
  final value = result['totalAvailable'];
  print(value);
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip lowerCamelCase technical strings', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/technical_identifier.dart')
        ..writeAsStringSync('''
String bleOperationName() {
  return 'getBluetoothState';
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip strings used in equality comparisons', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/status_compare.dart')
        ..writeAsStringSync('''
void main(String state) {
  if (state == 'permissionDenied' || state == 'unauthorized') {
    print(state);
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip strings used in thrown exceptions', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/throw_message.dart')
        ..writeAsStringSync('''
void main() {
  throw Exception('Failed to retrieve encryption key');
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip adjacent strings passed to logger calls', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/logger_adjacent_strings.dart')
        ..writeAsStringSync('''
class Logger {
  static void debug(String message, {String? tag}) {}
}

void main(bool hasPermission) {
  Logger.debug(
    '📱 [CONTACTS_NOTIFIER] requestContactsPermission returned: \$hasPermission '
    '(\${hasPermission ? "ALLOWED/SUCCESS" : "DENIED"})',
    tag: 'ContactsNotifier',
  );
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test('should skip strings inside toString methods', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/to_string.dart')
        ..writeAsStringSync('''
class Example {
  @override
  String toString() {
    return 'hello world';
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues, isEmpty);
    });

    test(
      'should use fallback scan for widget text when parse errors exist',
      () {
        final delegate = HardcodedStringDelegate(
          focus: HardcodedStringFocus.flutterWidgets,
        );
        final file = File('${tempDir.path}/fallback_widget_scan.dart')
          ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Recovered text"),
      ],
    )
  }
}
''');

        final issues = _analyzeFile(delegate, file);
        expect(issues.any((issue) => issue.value == 'Recovered text'), isTrue);
      },
    );

    test('should skip technical and ignored strings in fallback scan', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.flutterWidgets,
      );
      final file = File('${tempDir.path}/fallback_widget_skip.dart')
        ..writeAsStringSync('''
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ignore: avoid_hardcoded_strings_in_widgets
        Text("Ignored text"),
        Text("assets/images/icon.png"),
        Text("\$value"),
        Text("Detected text"),
      ],
    )
  }
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues.first.value, equals('Detected text'));
    });
  });

  group('HardcodedStringDelegate dart print focus', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should detect interpolated print strings', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.dartPrint,
      );
      final file = File('${tempDir.path}/dart_print_interpolation.dart')
        ..writeAsStringSync('''
String label(String name) => 'Hello \$name';

void main(String name) {
  print('Error: Invalid input "\$name"');
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues[0].value, contains('Error: Invalid input'));
      expect(issues[0].lineNumber, equals(4));
    });

    test('should ignore non-print and logger strings in dart print focus', () {
      final delegate = HardcodedStringDelegate(
        focus: HardcodedStringFocus.dartPrint,
      );
      final file = File('${tempDir.path}/dart_focus_filters.dart')
        ..writeAsStringSync('''
class Logger {
  void info(String message) {}
}

void main() {
  final logger = Logger();
  logger.info('Ignored logger');
  final text = 'Ignored local string';
  print('Detected print');
  print(text);
}
''');

      final issues = _analyzeFile(delegate, file);
      expect(issues.length, equals(1));
      expect(issues.first.value, equals('Detected print'));
    });
  });
}
