import 'package:args/args.dart';
import 'package:test/test.dart';

import '../../bin/console/console_input.dart';
import '../../bin/console/console_common.dart';

void main() {
  group('ConsoleInput parsing', () {
    late ArgParser parser;

    setUp(() {
      parser = createConsoleArgParser();
    });

    test('should parse --help flag correctly', () {
      final input = parseConsoleInput(['--help'], parser);
      expect(input.showHelp, isTrue);
    });

    test('should parse --version flag correctly', () {
      final input = parseConsoleInput(['--version'], parser);
      expect(input.showVersion, isTrue);
    });

    test('should parse --help-ignore flag correctly', () {
      final input = parseConsoleInput(['--help-ignore'], parser);
      expect(input.showIgnoresInstructions, isTrue);
    });

    test('should parse --help-score flag correctly', () {
      final input = parseConsoleInput(['--help-score'], parser);
      expect(input.showScoreInstructions, isTrue);
    });

    test('should parse --input flag correctly', () {
      final input = parseConsoleInput(['--input', '/some/path'], parser);
      expect(input.path, equals('/some/path'));
    });

    test('should parse -i short flag correctly', () {
      final input = parseConsoleInput(['-i', '/some/path'], parser);
      expect(input.path, equals('/some/path'));
    });

    test('should parse positional argument correctly', () {
      final input = parseConsoleInput(['/some/path'], parser);
      expect(input.path, equals('/some/path'));
    });

    test('should use current directory when no input provided', () {
      final input = parseConsoleInput([], parser);
      expect(input.path, equals('.'));
    });

    test('should prioritize --input over positional argument', () {
      final input = parseConsoleInput([
        '--input',
        '/input/path',
        '/positional/path',
      ], parser);
      expect(input.path, equals('/input/path'));
    });

    test('should parse --fix flag correctly', () {
      final input = parseConsoleInput(['--fix'], parser);
      expect(input.fix, isTrue);
    });
    test('should parse --svg shortcut correctly', () {
      final input = parseConsoleInput(['--svg'], parser);
      expect(input.generateSvg, isTrue);
      expect(input.generateFolderSvg, isTrue);
      expect(input.generateSizeSvg, isTrue);
    });

    test('should parse --svg-files flag correctly', () {
      final input = parseConsoleInput(['--svg-files'], parser);
      expect(input.generateSvg, isTrue);
      expect(input.generateFolderSvg, isFalse);
      expect(input.generateSizeSvg, isFalse);
    });

    test('should parse --svg-folders flag correctly', () {
      final input = parseConsoleInput(['--svg-folders'], parser);
      expect(input.generateFolderSvg, isTrue);
    });

    test('should parse --svg-loc flag correctly', () {
      final input = parseConsoleInput(['--svg-loc'], parser);
      expect(input.generateSizeSvg, isTrue);
    });

    test('should parse --mermaid flag correctly', () {
      final input = parseConsoleInput(['--mermaid'], parser);
      expect(input.generateMermaid, isTrue);
    });

    test('should parse --plantuml flag correctly', () {
      final input = parseConsoleInput(['--plantuml'], parser);
      expect(input.generatePlantUML, isTrue);
    });

    test('should parse --json flag correctly', () {
      final input = parseConsoleInput(['--json'], parser);
      expect(input.outputJson, isTrue);
    });

    test('should parse --output flag correctly', () {
      final input = parseConsoleInput(['--output', 'reports'], parser);
      expect(input.outputDirectory, equals('reports'));
    });

    test('should parse per-output path flags correctly', () {
      final input = parseConsoleInput([
        '--output-svg-files',
        'a.svg',
        '--output-svg-folders',
        'b.svg',
        '--output-svg-loc',
        'c.svg',
        '--output-mermaid',
        'd.mmd',
        '--output-plantuml',
        'e.puml',
      ], parser);
      expect(input.outputSvgFilesPath, equals('a.svg'));
      expect(input.outputSvgFoldersPath, equals('b.svg'));
      expect(input.outputSvgLocPath, equals('c.svg'));
      expect(input.outputMermaidPath, equals('d.mmd'));
      expect(input.outputPlantUmlPath, equals('e.puml'));
    });

    test('should parse --no-colors flag correctly', () {
      final input = parseConsoleInput(['--no-colors'], parser);
      expect(input.noColors, isTrue);
    });

    test('should parse --list flag correctly', () {
      final input = parseConsoleInput(['--list', 'full'], parser);
      expect(input.listMode, equals(ReportListMode.full));
      expect(input.listItemLimit, equals(defaultListItemLimit));
    });

    test('should parse numeric --list limit correctly', () {
      final input = parseConsoleInput(['--list', '3'], parser);
      expect(input.listMode, equals(ReportListMode.partial));
      expect(input.listItemLimit, equals(3));
    });

    test('should parse --excluded flag correctly', () {
      final input = parseConsoleInput(['--excluded'], parser);
      expect(input.listExcluded, isTrue);
    });

    test('should parse --literals flag correctly', () {
      final input = parseConsoleInput(['--literals'], parser);
      expect(input.listLiterals, isTrue);
    });

    test('should parse --exclude flag correctly', () {
      final input = parseConsoleInput([
        '--exclude',
        '**/generated/**',
        '--exclude',
        '**/test/**',
      ], parser);
      expect(input.excludePatterns, equals(['**/generated/**', '**/test/**']));
    });

    test('should parse multiple flags together', () {
      final input = parseConsoleInput([
        '--help',
        '--fix',
        '--svg-files',
        '--json',
      ], parser);
      expect(input.showHelp, isTrue);
      expect(input.fix, isTrue);
      expect(input.generateSvg, isTrue);
      expect(input.outputJson, isTrue);
    });

    test('should have correct default values', () {
      final input = parseConsoleInput([], parser);
      expect(input.path, equals('.'));
      expect(input.fix, isFalse);
      expect(input.generateSvg, isFalse);
      expect(input.generateMermaid, isFalse);
      expect(input.generatePlantUML, isFalse);
      expect(input.generateFolderSvg, isFalse);
      expect(input.generateSizeSvg, isFalse);
      expect(input.outputDirectory, isNull);
      expect(input.outputSvgFilesPath, isNull);
      expect(input.outputSvgFoldersPath, isNull);
      expect(input.outputSvgLocPath, isNull);
      expect(input.outputMermaidPath, isNull);
      expect(input.outputPlantUmlPath, isNull);
      expect(input.outputJson, isFalse);
      expect(input.listMode, equals(ReportListMode.partial));
      expect(input.listItemLimit, equals(defaultListItemLimit));
      expect(input.listExcluded, isFalse);
      expect(input.listLiterals, isFalse);
      expect(input.excludePatterns, isEmpty);
      expect(input.showHelp, isFalse);
      expect(input.showVersion, isFalse);
      expect(input.showIgnoresInstructions, isFalse);
      expect(input.showScoreInstructions, isFalse);
      expect(input.noColors, isFalse);
    });
  });

  group('ConsoleInput validation', () {
    late ArgParser parser;

    setUp(() {
      parser = createConsoleArgParser();
    });

    test('should handle invalid arguments gracefully', () {
      expect(
        () => parseConsoleInput(['--invalid-flag'], parser),
        throwsA(isA<FormatException>()),
      );
    });

    test('should handle invalid --list values gracefully', () {
      expect(
        () => parseConsoleInput(['--list', 'invalid'], parser),
        throwsA(isA<FormatException>()),
      );
    });

    test('should reject non-positive numeric --list values', () {
      expect(
        () => parseConsoleInput(['--list', '0'], parser),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ArgParser creation', () {
    test('should create parser with correct options', () {
      final parser = createConsoleArgParser();

      // Test that all expected flags are present
      expect(parser.options, contains('input'));
      expect(parser.options, contains('fix'));
      expect(parser.options, contains('svg'));
      expect(parser.options, contains('svg-files'));
      expect(parser.options, contains('mermaid'));
      expect(parser.options, contains('plantuml'));
      expect(parser.options, contains('svg-folders'));
      expect(parser.options, contains('svg-loc'));
      expect(parser.options, contains('output'));
      expect(parser.options, contains('output-svg-files'));
      expect(parser.options, contains('output-svg-folders'));
      expect(parser.options, contains('output-svg-loc'));
      expect(parser.options, contains('output-mermaid'));
      expect(parser.options, contains('output-plantuml'));
      expect(parser.options, contains('json'));
      expect(parser.options, contains('list'));
      expect(parser.options, contains('version'));
      expect(parser.options, contains('exclude'));
      expect(parser.options, contains('excluded'));
      expect(parser.options, contains('literals'));
      expect(parser.options, contains('help'));
      expect(parser.options, contains('help-ignore'));
      expect(parser.options, contains('help-score'));
      expect(parser.options, contains('no-colors'));
    });

    test('should have correct default values for options', () {
      final parser = createConsoleArgParser();
      final argResults = parser.parse([]);

      expect(argResults['input'], equals('.'));
      expect(argResults['fix'], isFalse);
      expect(argResults['svg'], isFalse);
      expect(argResults['svg-files'], isFalse);
      expect(argResults['mermaid'], isFalse);
      expect(argResults['plantuml'], isFalse);
      expect(argResults['svg-folders'], isFalse);
      expect(argResults['svg-loc'], isFalse);
      expect(argResults['output'], isNull);
      expect(argResults['output-svg-files'], isNull);
      expect(argResults['output-svg-folders'], isNull);
      expect(argResults['output-svg-loc'], isNull);
      expect(argResults['output-mermaid'], isNull);
      expect(argResults['output-plantuml'], isNull);
      expect(argResults['json'], isFalse);
      expect(argResults['list'], equals('partial'));
      expect(argResults['version'], isFalse);
      expect(argResults['exclude'], equals([]));
      expect(argResults['excluded'], isFalse);
      expect(argResults['literals'], isFalse);
      expect(argResults['help'], isFalse);
      expect(argResults['help-ignore'], isFalse);
      expect(argResults['help-score'], isFalse);
      expect(argResults['no-colors'], isFalse);
    });
  });
}
