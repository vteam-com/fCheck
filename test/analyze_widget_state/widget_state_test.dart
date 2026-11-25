import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A stateful widget, `Counter`, whose State is named [state], extending
/// [base].
String _widget(String state, {String base = 'StatefulWidget'}) =>
    '''
class Counter extends $base {
  const Counter();

  @override
  State<Counter> createState() => $state();
}
''';

/// The State of [_widget], named [state], extending [base].
String _state(String state, {String base = 'State'}) =>
    '''
class $state extends $base<Counter> {
  int count = 0;
}
''';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fcheck_widget_state_');
  });
  tearDown(() => project.deleteSync(recursive: true));

  void write(String path, String content) {
    File(p.join(project.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  ProjectMetrics analyze({Set<AnalyzerDomain>? enabled}) => AnalyzeFolder(
    project,
    enabledAnalyzers: enabled ?? const {AnalyzerDomain.widgetState},
  ).analyze();

  /// The issues, as (file, type) pairs.
  List<(String, WidgetStateIssueType)> issues() => [
    for (final issue in analyze().widgetStateIssues)
      (issue.filePath, issue.type),
  ];

  test('a private State beside its widget is in place', () {
    write(
      'lib/counter.dart',
      '${_widget('_CounterState')}\n${_state('_CounterState')}',
    );

    final metrics = analyze();

    expect(metrics.widgetStateIssues, isEmpty);
    expect(metrics.widgetStateCount, 1);
  });

  test('a public State no other file names is to make private', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n${_state('CounterState')}',
    );

    expect(issues(), [('lib/counter.dart', WidgetStateIssueType.public)]);
  });

  test('a State in a part file is apart from its widget; the test reaching '
      'into it is wrong', () {
    write(
      'lib/counter.dart',
      "part 'counter_state.dart';\n\n${_widget('CounterState')}",
    );
    write(
      'lib/counter_state.dart',
      "part of 'counter.dart';\n\n${_state('CounterState')}",
    );
    write(
      'test/counter_test.dart',
      'int countOf(Object state) => (state as CounterState).count;\n',
    );

    final found = analyze().widgetStateIssues;

    expect(
      [for (final issue in found) (issue.filePath, issue.type)],
      [
        ('lib/counter_state.dart', WidgetStateIssueType.apart),
        ('test/counter_test.dart', WidgetStateIssueType.reachedByTest),
      ],
    );
    expect(found.first.widget, 'Counter');
    expect(found.first.widgetFilePath, 'lib/counter.dart');
    expect(found.first.isInWidgetLibrary, isTrue);
  });

  test('a State another library of the app reaches by name stays public', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n${_state('CounterState')}',
    );
    write(
      'lib/panel.dart',
      "import 'counter.dart';\n\nfinal key = GlobalKey<CounterState>();\n",
    );

    expect(issues(), isEmpty);
  });

  test('a State in a library of its own is apart, out of the widget\'s '
      'library', () {
    write(
      'lib/counter.dart',
      "import 'counter_state.dart';\n\n${_widget('CounterState')}",
    );
    write(
      'lib/counter_state.dart',
      "import 'counter.dart';\n\n${_state('CounterState')}",
    );

    final issue = analyze().widgetStateIssues.singleWhere(
      (issue) => issue.type == WidgetStateIssueType.apart,
    );

    expect(issue.isInWidgetLibrary, isFalse);
  });

  test('knows Riverpod\'s stateful widgets and States', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState', base: 'ConsumerStatefulWidget')}\n'
          '${_state('CounterState', base: 'ConsumerState')}',
    );

    expect(issues(), [('lib/counter.dart', WidgetStateIssueType.public)]);
  });

  test('leaves a State whose line, or file, its ignore comment ends, a '
      'doc comment above it or not', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n/// Counts.\n'
          '${_state('CounterState').replaceFirst('{', '{ // ignore: fcheck_widget_state')}',
    );
    write(
      'lib/counter_state.dart',
      "// ignore: fcheck_widget_state\nimport 'counter.dart';\n\n"
          '${_state('OtherState')}',
    );

    expect(issues(), isEmpty);
  });

  test('a State only tests use is the tests\' fault, one issue a line, '
      'an ignored line left alone', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n@visibleForTesting\n${_state('CounterState')}',
    );
    write('test/counter_test.dart', '''
void check(Tester tester) {
  final CounterState state = tester.state<CounterState>(finder);
  print(state.count);
  final other = tester.state<CounterState>(finder); // ignore: fcheck_widget_state
}
''');

    final issue = analyze().widgetStateIssues.single;

    expect(issue.type, WidgetStateIssueType.reachedByTest);
    expect(issue.filePath, 'test/counter_test.dart');
    expect(issue.lineNumber, 2);
    expect(issue.state, 'CounterState');
  });

  test('a test naming a private State, which can\'t compile, reaches into '
      'it too', () {
    write(
      'lib/counter.dart',
      '${_widget('_CounterState')}\n${_state('_CounterState')}',
    );
    write('test/counter_test.dart', '_CounterState? state;\n');

    expect(issues(), [
      ('test/counter_test.dart', WidgetStateIssueType.reachedByTest),
    ]);
  });

  test('a test calling the widget\'s createState reaches into its State, '
      'whatever holds it', () {
    write(
      'lib/counter.dart',
      '${_widget('_CounterState')}\n${_state('_CounterState')}',
    );
    write('test/counter_test.dart', '''
void main() {
  late dynamic state;
  const counter = Counter();
  state = counter.createState();
  final other = Counter().createState();
}
''');

    expect(
      [
        for (final issue in analyze().widgetStateIssues)
          (issue.lineNumber, issue.state),
      ],
      [(4, '_CounterState'), (5, '_CounterState')],
    );
  });

  test('scores the issues, only when the project declares a State', () {
    write('lib/plain.dart', 'class Plain {}\n');

    final plain = analyze(enabled: AnalyzerDomain.values.toSet());
    expect(
      plain.analyzerScores
          .singleWhere((score) => score.key == 'widget_state')
          .enabled,
      isFalse,
    );

    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n${_state('CounterState')}',
    );

    final score = analyze(enabled: AnalyzerDomain.values.toSet()).analyzerScores
        .singleWhere((score) => score.key == 'widget_state');
    expect(score.enabled, isTrue);
    expect(score.issueCount, 1);
    expect(score.score, lessThan(1));
  });

  test('is configured as widget_state and reported in JSON', () {
    write(
      'lib/counter.dart',
      '${_widget('CounterState')}\n${_state('CounterState')}',
    );

    expect(AnalyzerDomain.widgetState.configName, 'widget_state');
    final json = analyze().toJson();
    expect(json['widgetStateIssues'], [
      {
        'type': 'public',
        'filePath': 'lib/counter.dart',
        'lineNumber': 8,
        'state': 'CounterState',
        'isInWidgetLibrary': true,
        'widget': {'name': 'Counter', 'filePath': 'lib/counter.dart'},
      },
    ]);
  });
}
