import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_issue.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_role.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_visitor.dart';
import 'package:test/test.dart';

/// The issues found in [content] in Flutter widget focus.
List<HardcodedStringIssue> _issuesIn(String content) {
  final unit = parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final visitor = HardcodedStringVisitor(
    'lib/page.dart',
    content,
    focus: HardcodedStringFocus.flutterWidgets,
    usesLocalization: true,
  );
  unit.accept(visitor);
  return visitor.foundIssues;
}

void main() {
  group('HardcodedStringSite', () {
    test('locates the string and its build context', () {
      const content = '''
class Page extends StatelessWidget {
  Widget build(BuildContext context) {
    return Text('Unknown Venue');
  }
}
''';
      final site = _issuesIn(content).single.site!;

      expect(
        content.substring(site.offset, site.offset + site.length),
        "'Unknown Venue'",
      );
      expect(site.textParts, ['Unknown Venue']);
      expect(site.interpolations, isEmpty);
      expect(site.buildContextName, 'context');
      expect(site.constKeywordOffsets, isEmpty);
    });

    test('splits the text around interpolations', () {
      const content = r'''
class Page extends StatelessWidget {
  Widget build(BuildContext ctx) {
    return Text('Error: $error in ${file.name}!');
  }
}
''';
      final site = _issuesIn(content).single.site!;

      expect(site.textParts, ['Error: ', ' in ', '!']);
      expect(site.interpolations, ['error', 'file.name']);
      expect(site.buildContextName, 'ctx');
    });

    test('lists enclosing const keywords, innermost first', () {
      const content = '''
class Page extends StatelessWidget {
  Widget build(BuildContext context) {
    return const Padding(child: const Text('Search performers'));
  }
}
''';
      final site = _issuesIn(content).single.site!;

      expect(site.constKeywordOffsets, [
        content.indexOf('const Text'),
        content.indexOf('const Padding'),
      ]);
      expect(site.isWidgetOutput, isTrue);
    });

    test('takes adjacent strings whole', () {
      const content = '''
class Page extends StatelessWidget {
  Widget build(BuildContext context) {
    return Text('No concerts yet. '
        'Add your first one.');
  }
}
''';
      final sites = {
        for (final issue in _issuesIn(content)) issue.site!.offset,
      };
      final site = _issuesIn(content).first.site!;

      expect(sites, hasLength(1));
      expect(site.textParts, ['No concerts yet. Add your first one.']);
    });

    test('has a context in State methods but not in initState', () {
      const content = '''
class _PageState extends State<Page> {
  void initState() {
    title = describe('Loading concerts');
  }

  void _save() {
    show(Text('Concert saved'));
  }
}
''';
      final issues = _issuesIn(content);
      String? contextOf(String value) => issues
          .firstWhere((issue) => issue.value == value)
          .site!
          .buildContextName;

      expect(contextOf('Loading concerts'), isNull);
      expect(contextOf('Concert saved'), 'context');
    });

    test('has no context in a model', () {
      const content = '''
class Concert {
  String get performerName => performer ?? 'Unknown Performer';
}
''';
      final site = _issuesIn(content).single.site!;

      expect(site.buildContextName, isNull);
      expect(site.isWidgetOutput, isFalse);
    });

    test('names the callee and argument the string is passed as', () {
      const content = '''
class Page extends StatelessWidget {
  Widget build(BuildContext context) {
    final match = error.contains('permission denied');
    return PopupMenuItem(
      value: 'edit concert',
      child: Text(isNew ? 'Add concert' : 'Save concert'),
    );
  }
}
''';
      final issues = _issuesIn(content);
      (String?, String?) argumentOf(String value) {
        final site = issues.firstWhere((issue) => issue.value == value).site!;
        return (site.calleeName, site.argumentName);
      }

      expect(argumentOf('permission denied'), ('contains', null));
      expect(argumentOf('edit concert'), ('PopupMenuItem', 'value'));
      expect(argumentOf('Save concert'), ('Text', null));
    });

    test('looks past a wildcard parameter for the context', () {
      const content = '''
class Page extends StatelessWidget {
  Widget build(BuildContext context) {
    return Builder(builder: (BuildContext _) => Text('Concert list'));
  }
}
''';
      expect(_issuesIn(content).single.site!.buildContextName, 'context');
    });
  });

  group('HardcodedStringSite.role', () {
    const content = r'''
class ConcertPage extends StatefulWidget {
  const ConcertPage({required this.heading});
  final String heading;
  State<ConcertPage> createState() => _ConcertPageState();
}

class _ConcertPageState extends State<ConcertPage> {
  Widget build(BuildContext context) {
    final caption = 'Concert details';
    return Column(children: [
      Text(caption),
      Text(widget.heading),
      ConcertPage(heading: 'Upcoming shows'),
      PopupMenuItem(value: 'edit item', child: Text(context.l10n.edit)),
      Text(_status('sold out')),
    ]);
  }

  void _showError(String error) {
    if (error.contains('Firebase')) return;
    switch (error) {
      case 'quota exceeded':
        return;
    }
  }

  Future<void> _removeTicket(int index) =>
      _removePhoto(index, 'ticket photos');

  Future<void> _removePhoto(int index, String photoType) async {
    showMessage(context.l10n.onlyDeleteOwnPhotos(photoType.toLowerCase()));
  }

  String _status(String code) => code == 'sold out' ? code : 'on sale';

  String _label() => 'Venue unknown';

  void _log() => sendToServer(_label());
}
''';

    /// The role and evidence of the string [value] in [content].
    (HardcodedStringRole, String) roleOf(String value) {
      final site = _issuesIn(content)
          .firstWhere((issue) => issue.value == value)
          .site!;
      return (site.role, site.roleEvidence);
    }

    test('finds text users read', () {
      expect(roleOf('Concert details'), (
        HardcodedStringRole.presentation,
        'caption → Text(…)',
      ));
      expect(roleOf('Upcoming shows'), (
        HardcodedStringRole.presentation,
        'heading → Text(…)',
      ));
    });

    test('finds values the code compares or looks up', () {
      expect(roleOf('Firebase'), (HardcodedStringRole.data, '.contains(…)'));
      expect(roleOf('quota exceeded'), (
        HardcodedStringRole.data,
        'switch case',
      ));
      expect(roleOf('edit item'), (
        HardcodedStringRole.data,
        'PopupMenuItem(value:)',
      ));
      // Compared in _status, even though also shown
      expect(roleOf('sold out').$1, HardcodedStringRole.data);
    });

    test('finds text shown only inside another message', () {
      expect(roleOf('ticket photos'), (
        HardcodedStringRole.fragment,
        'photoType → l10n.onlyDeleteOwnPhotos(…)',
      ));
    });

    test('reads names of arguments declared elsewhere', () {
      const elsewhere = '''
class Page extends StatelessWidget {
  Widget build(BuildContext context) {
    return SearchTab(searchHint: 'Search venues', ownerId: 'nobody yet');
  }
}
''';
      final issues = _issuesIn(elsewhere);
      (HardcodedStringRole, String) roleIn(String value) {
        final site = issues.firstWhere((issue) => issue.value == value).site!;
        return (site.role, site.roleEvidence);
      }

      expect(roleIn('Search venues'), (
        HardcodedStringRole.presentation,
        'SearchTab(searchHint:)',
      ));
      expect(roleIn('nobody yet'), (
        HardcodedStringRole.data,
        'SearchTab(ownerId:)',
      ));
    });

    test('follows collections and default values, not null checks', () {
      const more = r'''
class Placeholder extends StatelessWidget {
  const Placeholder({this.emptyText = 'Nothing here yet'});
  final String emptyText;

  Widget build(BuildContext context) {
    final uri = Uri.https('itunes.apple.com', '/search', {'media': 'music'});
    final warning = loaded ? null : 'Still loading data';
    if (warning == null) return Text(emptyText);
    return Text(warning);
  }
}
''';
      final issues = _issuesIn(more);
      HardcodedStringRole roleIn(String value) =>
          issues.firstWhere((issue) => issue.value == value).site!.role;

      expect(roleIn('music'), HardcodedStringRole.data);
      expect(roleIn('Nothing here yet'), HardcodedStringRole.presentation);
      expect(roleIn('Still loading data'), HardcodedStringRole.presentation);
    });

    test('follows returned values to their callers', () {
      expect(roleOf('on sale'), (
        HardcodedStringRole.presentation,
        '_status() → Text(…)',
      ));
      expect(roleOf('Venue unknown'), (
        HardcodedStringRole.unknown,
        '_label() → sendToServer(…)',
      ));
    });

    test('follows switch expression results, and compares their cases', () {
      const switches = '''
class Page extends StatelessWidget {
  Widget build(BuildContext context) {
    final label = switch (kind) { 'paid' => 'Ticket paid', _ => 'Unpaid' };
    return Column(children: [
      Text(label),
      Text(switch (kind) { Kind.vip => 'VIP entrance', _ => 'Main door' }),
    ]);
  }
}
''';
      final issues = _issuesIn(switches);
      (HardcodedStringRole, String) roleIn(String value) {
        final site = issues.firstWhere((issue) => issue.value == value).site!;
        return (site.role, site.roleEvidence);
      }

      expect(roleIn('Ticket paid'), (
        HardcodedStringRole.presentation,
        'label → Text(…)',
      ));
      expect(roleIn('VIP entrance'), (
        HardcodedStringRole.presentation,
        'Text(…)',
      ));
      expect(roleIn('paid'), (HardcodedStringRole.data, 'switch case'));
    });
  });
}
