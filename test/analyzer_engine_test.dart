import 'dart:io';
import 'package:fcheck/fcheck.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/models/code_size_thresholds.dart';
import 'package:fcheck/src/analyzers/dead_code/dead_code_issue.dart';
import 'package:fcheck/src/analyzers/documentation/documentation_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AnalyzerEngine', () {
    late Directory tempDir;
    late AnalyzeFolder analyzer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fcheck_test_');
      analyzer = AnalyzeFolder(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('should analyze empty directory', () {
      final metrics = analyzer.analyze();

      expect(metrics.totalFolders, equals(0));
      expect(metrics.totalFiles, equals(0));
      expect(metrics.totalDartFiles, equals(0));
      expect(metrics.totalLinesOfCode, equals(0));
      expect(metrics.totalCommentLines, equals(0));
      expect(metrics.fileMetrics, isEmpty);
      expect(metrics.hardcodedStringIssues, isEmpty);
      expect(metrics.magicNumberIssues, isEmpty);
      expect(metrics.sourceSortIssues, isEmpty);
      expect(metrics.duplicateCodeIssues, isEmpty);
    });

    test('should analyze directory with Dart files', () {
      // Create a simple Dart file
      File('${tempDir.path}/example.dart').writeAsStringSync('''
// This is a comment
void main() {
  print("Hello World"); // Another comment
}
''');

      // Create a subdirectory with another file
      final subDir = Directory('${tempDir.path}/lib')..createSync();
      File('${subDir.path}/utils.dart').writeAsStringSync('''
// Utility functions
class Utils {
  static void helper() {
    // Do something
  }
}
''');

      final metrics = analyzer.analyze();

      expect(metrics.totalFolders, equals(1)); // lib directory
      expect(metrics.totalFiles, equals(2)); // 2 Dart files
      expect(metrics.totalDartFiles, equals(2));
      expect(metrics.totalLinesOfCode, greaterThan(0));
      expect(metrics.totalCommentLines, greaterThan(0));
      expect(metrics.fileMetrics.length, equals(2));
    });

    test('should detect hardcoded strings in analyzed files', () {
      File('${tempDir.path}/hardcoded.dart').writeAsStringSync('''
void main() {
  print("This is a hardcoded string");
  const String key = "safe"; // This should not be detected
}
''');

      final metrics = analyzer.analyze();

      expect(metrics.hardcodedStringIssues.length, equals(1));
      expect(
        metrics.hardcodedStringIssues[0].value,
        equals('This is a hardcoded string'),
      );
    });

    test('should detect magic numbers in analyzed files', () {
      File('${tempDir.path}/magic.dart').writeAsStringSync('''
void main() {
  print(7);
  const skipValue = 5;
}
''');

      final metrics = analyzer.analyze();
      expect(metrics.magicNumberIssues.length, equals(1));
      expect(metrics.magicNumberIssues.first.value, equals('7'));
    });

    test('should detect all supported secret patterns', () {
      File('${tempDir.path}/secrets.dart').writeAsStringSync('''
void main() {
  const aws = "AKIA1234567890ABCD12";
  final apiKey = "aB3dE5fG7hJ9kL1mN3pQ5rS7";
  final bearer = "Bearer AbCdEfGhIjKlMnOpQrStUvWxYz1234567890";
  const privateKeyHeader = "-----BEGIN RSA PRIVATE KEY-----";
  const email = "dev.team@example.com";
  const stripe = "sk_live_1234567890abcdefghijklmn";
  const githubPat = "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
  const entropyBlob = "QWERTYUIOPASDFGHJKLZXCVBNM1234567890abcd";
  print(aws + apiKey + bearer + privateKeyHeader + email + stripe + githubPat + entropyBlob);
}
''');

      final metrics = analyzer.analyze();
      final detectedTypes = metrics.secretIssues
          .map((issue) => issue.secretType)
          .toSet();

      expect(detectedTypes, contains('aws_access_key'));
      expect(detectedTypes, contains('generic_secret'));
      expect(detectedTypes, contains('bearer_token'));
      expect(detectedTypes, contains('private_key'));
      expect(detectedTypes, contains('email_pii'));
      expect(detectedTypes, contains('stripe_key'));
      expect(detectedTypes, contains('github_pat'));
      expect(detectedTypes, contains('high_entropy'));
    });

    test(
      'should detect generic secret assigned with triple-quoted literal',
      () {
        File('${tempDir.path}/triple_secret.dart').writeAsStringSync('''
void main() {
  final private_key = """AbC123xYz789LmN456OpQ901RsT234UvW""";
  print(private_key);
}
''');

        final metrics = analyzer.analyze();
        expect(
          metrics.secretIssues.any(
            (issue) => issue.secretType == 'generic_secret',
          ),
          isTrue,
        );
      },
    );

    test(
      'should skip secret scanning when ignore directive is in first 10 lines',
      () {
        File('${tempDir.path}/ignored_secrets.dart').writeAsStringSync('''
// ignore: fcheck_secrets
void main() {
  const stripe = "sk_live_1234567890abcdefghijklmn";
  print(stripe);
}
''');

        final metrics = analyzer.analyze();
        expect(
          metrics.secretIssues.any(
            (issue) => (issue.filePath ?? '').endsWith('ignored_secrets.dart'),
          ),
          isFalse,
        );
      },
    );

    test(
      'should not honor secrets ignore directive when declared after first 10 lines',
      () {
        File('${tempDir.path}/late_ignore_secrets.dart').writeAsStringSync('''
void line01() {}
void line02() {}
void line03() {}
void line04() {}
void line05() {}
void line06() {}
void line07() {}
void line08() {}
void line09() {}
void line10() {}
// ignore: fcheck_secrets
void main() {
  const stripe = "sk_live_1234567890abcdefghijklmn";
  print(stripe);
}
''');

        final metrics = analyzer.analyze();
        expect(
          metrics.secretIssues.any(
            (issue) =>
                (issue.filePath ?? '').endsWith('late_ignore_secrets.dart') &&
                issue.secretType == 'stripe_key',
          ),
          isTrue,
        );
      },
    );

    test('should count derived widget implementations by type', () {
      File('${tempDir.path}/base.dart').writeAsStringSync('''
abstract class BaseStateless extends StatelessWidget {}
abstract class BaseStateful extends StatefulWidget {}
''');
      File('${tempDir.path}/derived.dart').writeAsStringSync('''
class ScreenA extends BaseStateless {}
class ScreenB extends BaseStateful {}
''');

      final metrics = analyzer.analyze();

      expect(metrics.totalStatelessWidgetCount, equals(2));
      expect(metrics.totalStatefulWidgetCount, equals(2));
    });

    test(
      'should report documentation issue paths relative to analysis root',
      () {
        final file = File('${tempDir.path}/lib/feature/service.dart')
          ..createSync(recursive: true);
        file.writeAsStringSync('''
class Service {}
''');

        final metrics = analyzer.analyze();
        final readmeIssue = metrics.documentationIssues.firstWhere(
          (issue) => issue.type == DocumentationIssueType.missingReadme,
        );
        final classIssue = metrics.documentationIssues.firstWhere(
          (issue) =>
              issue.type == DocumentationIssueType.undocumentedPublicClass,
        );

        expect(readmeIssue.filePath, equals('README.md'));
        expect(
          classIssue.filePath,
          equals(p.join('lib', 'feature', 'service.dart')),
        );
      },
    );

    test('should report dead code issue paths relative to analysis root', () {
      final file = File('${tempDir.path}/lib/feature/dead.dart')
        ..createSync(recursive: true);
      file.writeAsStringSync('''
void main() {
  final unused = 42;
  print('ok');
}
''');

      final metrics = analyzer.analyze();
      final unusedVariableIssue = metrics.deadCodeIssues.firstWhere(
        (issue) => issue.type == DeadCodeIssueType.unusedVariable,
      );

      expect(
        unusedVariableIssue.filePath,
        equals(p.join('lib', 'feature', 'dead.dart')),
      );
    });

    test(
      'should treat export directive dependencies as reachable for dead-file analysis',
      () {
        final libDir = Directory('${tempDir.path}/lib')..createSync();
        File('${libDir.path}/main.dart').writeAsStringSync('''
import 'barrel.dart';

void main() {
  runApp();
}
''');
        File('${libDir.path}/barrel.dart').writeAsStringSync('''
export 'exported.dart';

void runApp() {}
''');
        File('${libDir.path}/exported.dart').writeAsStringSync('''
class ExportedType {}
''');

        final metrics = analyzer.analyze();
        final deadFileIssues = metrics.deadCodeIssues
            .where((issue) => issue.type == DeadCodeIssueType.deadFile)
            .toList();

        expect(
          deadFileIssues.any(
            (issue) => issue.filePath.endsWith('exported.dart'),
          ),
          isFalse,
        );
      },
    );

    test(
      'should treat part directive dependencies as reachable for dead-file analysis',
      () {
        final libDir = Directory('${tempDir.path}/lib')..createSync();
        File('${libDir.path}/main.dart').writeAsStringSync('''
import 'owner.dart';

void main() {
  bootstrap();
}
''');
        File('${libDir.path}/owner.dart').writeAsStringSync('''
part 'owner_part.dart';

void bootstrap() {}
''');
        File('${libDir.path}/owner_part.dart').writeAsStringSync('''
part of 'owner.dart';

class PartOnlyType {}
''');

        final metrics = analyzer.analyze();
        final deadFileIssues = metrics.deadCodeIssues
            .where((issue) => issue.type == DeadCodeIssueType.deadFile)
            .toList();

        expect(
          deadFileIssues.any(
            (issue) => issue.filePath.endsWith('owner_part.dart'),
          ),
          isFalse,
        );
      },
    );

    test(
      'should mark catch variables, function-typed parameters, and operator usages as used',
      () {
        File('${tempDir.path}/operators_coverage.dart').writeAsStringSync('''
class Ops {
  Ops(this.value);

  int value;

  Ops operator +(Ops other) => Ops(value + other.value);
  Ops operator -(Ops other) => Ops(value - other.value);
  Ops operator *(Ops other) => Ops(value * other.value);
  Ops operator /(Ops other) => Ops(value ~/ other.value);
  Ops operator ~/(Ops other) => Ops(value ~/ other.value);
  Ops operator %(Ops other) => Ops(value % other.value);
  bool operator >(Ops other) => value > other.value;
  bool operator >=(Ops other) => value >= other.value;
  bool operator <(Ops other) => value < other.value;
  bool operator <=(Ops other) => value <= other.value;
  Ops operator &(Ops other) => Ops(value & other.value);
  Ops operator |(Ops other) => Ops(value | other.value);
  Ops operator ^(Ops other) => Ops(value ^ other.value);
  Ops operator <<(int bits) => Ops(value << bits);
  Ops operator >>(int bits) => Ops(value >> bits);
  Ops operator >>>(int bits) => Ops(value >>> bits);
  Ops operator ~() => Ops(~value);

  int operator [](int index) => value + index;
  void operator []=(int index, int next) {
    value = next + index;
  }
}

int increment(int input) => input + 1;

int applyTwice(int callback(int value), int input) {
  return callback(callback(input));
}

void main() {
  final left = Ops(8);
  final right = Ops(2);

  left + right;
  left - right;
  left * right;
  left / right;
  left ~/ right;
  left % right;
  left > right;
  left >= right;
  left < right;
  left <= right;
  left & right;
  left | right;
  left ^ right;
  left << 1;
  left >> 1;
  left >>> 1;
  ~left;

  left[0];
  left[0] = 5;

  var counter = 0;
  counter++;
  ++counter;
  counter--;
  --counter;

  var numeric = 32;
  numeric += 1;
  numeric -= 1;
  numeric *= 2;
  numeric /= 2;
  numeric ~/= 2;
  numeric %= 5;

  var bits = 8;
  bits &= 3;
  bits |= 1;
  bits ^= 2;
  bits <<= 1;
  bits >>= 1;
  bits >>>= 1;

  applyTwice(increment, 1);

  try {
    throw StateError('boom');
  } catch (e, st) {
    if ('\$e\$st'.isEmpty) {
      print('never');
    }
  }
}
''');

        final metrics = analyzer.analyze();
        final deadFunctionIssues = metrics.deadCodeIssues
            .where((issue) => issue.type == DeadCodeIssueType.deadFunction)
            .toList();
        final unusedVariableIssues = metrics.deadCodeIssues
            .where((issue) => issue.type == DeadCodeIssueType.unusedVariable)
            .toList();

        expect(deadFunctionIssues.any((issue) => issue.name == '[]'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '[]='), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '+'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '-'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '*'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '/'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '~/'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '%'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '&'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '|'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '^'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '<<'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '>>'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '>>>'), isFalse);
        expect(deadFunctionIssues.any((issue) => issue.name == '~'), isFalse);
        expect(
          deadFunctionIssues.any((issue) => issue.name == 'applyTwice'),
          isFalse,
        );
        expect(
          unusedVariableIssues.any((issue) => issue.name == 'callback'),
          isFalse,
        );
        expect(unusedVariableIssues.any((issue) => issue.name == 'e'), isFalse);
        expect(
          unusedVariableIssues.any((issue) => issue.name == 'st'),
          isFalse,
        );
      },
    );

    test(
      'should suppress non-actionable generated warnings while keeping dead-code usage edges',
      () {
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: sample
version: 0.0.1
''');

        final libDir = Directory('${tempDir.path}/lib')..createSync();
        File('${libDir.path}/main.dart').writeAsStringSync('''
import 'api.g.dart';

void main() {
  generatedCall();
}
''');

        File('${libDir.path}/service.dart').writeAsStringSync('''
void helper() {}

void unusedServiceFunction() {}
''');

        File('${libDir.path}/api.g.dart').writeAsStringSync('''
import 'service.dart';

class GeneratedOne {}
class GeneratedTwo {}

void generatedCall() {
  final count = 42;
  if (count > 0) {
    helper();
    print("generated");
  }
}

void generatedDead() {}
''');

        final metrics = AnalyzeFolder(
          tempDir,
          codeSizeThresholds: const CodeSizeThresholds(
            maxFileLoc: 1,
            maxClassLoc: 1,
            maxFunctionLoc: 1,
            maxMethodLoc: 1,
          ),
        ).analyze();

        expect(
          metrics.hardcodedStringIssues.any(
            (issue) => issue.filePath.endsWith('api.g.dart'),
          ),
          isFalse,
        );
        expect(
          metrics.magicNumberIssues.any(
            (issue) => issue.filePath.endsWith('api.g.dart'),
          ),
          isFalse,
        );
        expect(
          metrics.codeSizeArtifacts.any(
            (artifact) => artifact.filePath.endsWith('api.g.dart'),
          ),
          isFalse,
        );

        final generatedMetric = metrics.fileMetrics.firstWhere(
          (metric) => metric.path.endsWith('api.g.dart'),
        );
        expect(generatedMetric.ignoreOneClassPerFile, isTrue);
        expect(generatedMetric.isOneClassPerFileCompliant, isTrue);

        expect(
          metrics.deadCodeIssues.any(
            (issue) =>
                issue.type == DeadCodeIssueType.deadFunction &&
                issue.name == 'helper',
          ),
          isFalse,
        );
        expect(
          metrics.deadCodeIssues.any(
            (issue) =>
                issue.filePath.endsWith('api.g.dart') &&
                issue.type == DeadCodeIssueType.deadFunction,
          ),
          isFalse,
        );
        expect(
          metrics.deadCodeIssues.any(
            (issue) =>
                issue.type == DeadCodeIssueType.deadFunction &&
                issue.name == 'unusedServiceFunction',
          ),
          isTrue,
        );
      },
    );

    test(
      'should expose code-size artifacts through analyze path and JSON output',
      () {
        final file = File('${tempDir.path}/lib/code_size_sample.dart')
          ..createSync(recursive: true);
        file.writeAsStringSync('''
class AccountService {
  AccountService();

  AccountService.named();

  void save() {
    final local = 1;
    print(local);
  }
}

int topSum(int a, int b) {
  return a + b;
}
''');

        final metrics = analyzer.analyze();

        final fileArtifact = metrics.codeSizeArtifacts.firstWhere(
          (artifact) =>
              artifact.kind == CodeSizeArtifactKind.file &&
              artifact.filePath.endsWith('code_size_sample.dart'),
        );
        expect(fileArtifact.name, equals('code_size_sample.dart'));
        expect(fileArtifact.isCallable, isFalse);
        expect(fileArtifact.qualifiedName, equals('code_size_sample.dart'));

        final classArtifact = metrics.codeSizeArtifacts.firstWhere(
          (artifact) =>
              artifact.kind == CodeSizeArtifactKind.classDeclaration &&
              artifact.name == 'AccountService' &&
              artifact.filePath.endsWith('code_size_sample.dart'),
        );
        expect(classArtifact.ownerName, isNull);
        expect(classArtifact.qualifiedName, equals('AccountService'));
        expect(classArtifact.isCallable, isFalse);

        final functionArtifact = metrics.codeSizeArtifacts.firstWhere(
          (artifact) =>
              artifact.kind == CodeSizeArtifactKind.function &&
              artifact.name == 'topSum' &&
              artifact.filePath.endsWith('code_size_sample.dart'),
        );
        expect(functionArtifact.ownerName, isNull);
        expect(functionArtifact.qualifiedName, equals('topSum'));
        expect(functionArtifact.isCallable, isTrue);

        final methodArtifact = metrics.codeSizeArtifacts.firstWhere(
          (artifact) =>
              artifact.kind == CodeSizeArtifactKind.method &&
              artifact.name == 'save' &&
              artifact.filePath.endsWith('code_size_sample.dart'),
        );
        expect(methodArtifact.ownerName, equals('AccountService'));
        expect(methodArtifact.qualifiedName, equals('AccountService.save'));
        expect(methodArtifact.isCallable, isTrue);

        final defaultConstructorArtifact = metrics.codeSizeArtifacts.firstWhere(
          (artifact) =>
              artifact.kind == CodeSizeArtifactKind.method &&
              artifact.name == 'AccountService' &&
              artifact.filePath.endsWith('code_size_sample.dart'),
        );
        expect(defaultConstructorArtifact.ownerName, equals('AccountService'));
        expect(
          defaultConstructorArtifact.qualifiedName,
          equals('AccountService.AccountService'),
        );

        final namedConstructorArtifact = metrics.codeSizeArtifacts.firstWhere(
          (artifact) =>
              artifact.kind == CodeSizeArtifactKind.method &&
              artifact.name == 'AccountService.named' &&
              artifact.filePath.endsWith('code_size_sample.dart'),
        );
        expect(namedConstructorArtifact.ownerName, equals('AccountService'));
        expect(
          namedConstructorArtifact.qualifiedName,
          equals('AccountService.AccountService.named'),
        );

        final jsonArtifacts =
            (metrics.toJson()['codeSize'] as Map<String, dynamic>)['artifacts']
                as List<dynamic>;

        expect(
          jsonArtifacts,
          contains(containsPair('qualifiedName', 'AccountService.save')),
        );
        expect(
          jsonArtifacts,
          contains(
            allOf(
              containsPair('name', 'save'),
              containsPair('ownerName', 'AccountService'),
              containsPair('kind', 'method'),
            ),
          ),
        );
      },
    );

    test(
      'should exclude localization Dart files from LOC code-size artifacts',
      () {
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: sample
version: 0.0.1
''');

        final libDir = Directory('${tempDir.path}/lib')..createSync();
        final l10nDir = Directory('${libDir.path}/l10n')..createSync();

        File('${l10nDir.path}/app_localizations.dart').writeAsStringSync('''
class AppLocalizations {
  String get title => 'Title';
}
''');

        File('${l10nDir.path}/app_localizations_en.dart').writeAsStringSync('''
class AppLocalizationsEn {
  String get title => 'Title';
}
''');

        File('${libDir.path}/feature.dart').writeAsStringSync('''
class Feature {
  void run() {
    print('ok');
  }
}
''');

        final metrics = AnalyzeFolder(
          tempDir,
          codeSizeThresholds: const CodeSizeThresholds(
            maxFileLoc: 1,
            maxClassLoc: 1,
            maxFunctionLoc: 1,
            maxMethodLoc: 1,
          ),
        ).analyze();

        expect(
          metrics.codeSizeArtifacts.any(
            (artifact) => artifact.filePath.contains('/lib/l10n/'),
          ),
          isFalse,
        );

        expect(
          metrics.codeSizeArtifacts.any(
            (artifact) => artifact.filePath.endsWith('feature.dart'),
          ),
          isTrue,
        );
      },
    );
  });
}
