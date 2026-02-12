import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Analyzer domains that can be enabled/disabled via `.fcheck`.
enum AnalyzerDomain {
  /// One class per file compliance rule.
  oneClassPerFile,

  /// Hardcoded string detection.
  hardcodedStrings,

  /// Magic number detection.
  magicNumbers,

  /// Flutter member sorting checks.
  sourceSorting,

  /// Layer dependency analysis.
  layers,

  /// Secret and token scanning.
  secrets,

  /// Dead code analysis.
  deadCode,

  /// Duplicate code analysis.
  duplicateCode,

  /// Documentation coverage and policy checks.
  documentation,
}

/// Helpers for mapping analyzer domains to configuration keys.
extension AnalyzerDomainName on AnalyzerDomain {
  /// Canonical key used in `.fcheck` config files.
  String get configName {
    switch (this) {
      case AnalyzerDomain.oneClassPerFile:
        return 'one_class_per_file';
      case AnalyzerDomain.hardcodedStrings:
        return 'hardcoded_strings';
      case AnalyzerDomain.magicNumbers:
        return 'magic_numbers';
      case AnalyzerDomain.sourceSorting:
        return 'source_sorting';
      case AnalyzerDomain.layers:
        return 'layers';
      case AnalyzerDomain.secrets:
        return 'secrets';
      case AnalyzerDomain.deadCode:
        return 'dead_code';
      case AnalyzerDomain.duplicateCode:
        return 'duplicate_code';
      case AnalyzerDomain.documentation:
        return 'documentation';
    }
  }
}

/// Parsed `.fcheck` configuration loaded from a project directory.
class FcheckConfig {
  /// The default config file name expected in a project directory.
  static const String fileName = '.fcheck';

  /// Default duplicate-code similarity threshold.
  static const double defaultDuplicateCodeSimilarityThreshold = 0.90;

  /// Default duplicate-code minimum token count.
  static const int defaultDuplicateCodeMinTokens = 20;

  /// Default duplicate-code minimum non-empty line count.
  static const int defaultDuplicateCodeMinNonEmptyLines = 10;

  /// Original input directory passed to the CLI.
  final Directory inputDirectory;

  /// Directory containing this `.fcheck` file.
  final Directory configDirectory;

  /// Optional path to the source config file.
  final File? sourceFile;

  /// Optional input root configured under `input.root`.
  final String? inputRoot;

  /// Exclude patterns from `input.exclude`.
  final List<String> excludePatterns;

  /// Analyzer default state (`on`/`off`) from `analyzers.default`.
  final bool analyzerDefaultEnabled;

  /// Explicitly enabled analyzers from `analyzers.enabled`.
  final Set<AnalyzerDomain> enabledAnalyzers;

  /// Explicitly disabled analyzers from `analyzers.disabled` and legacy ignores.
  final Set<AnalyzerDomain> disabledAnalyzers;

  /// Duplicate-code similarity threshold.
  final double duplicateCodeSimilarityThreshold;

  /// Duplicate-code minimum normalized token count.
  final int duplicateCodeMinTokens;

  /// Duplicate-code minimum non-empty line count.
  final int duplicateCodeMinNonEmptyLines;

  /// Creates a parsed `.fcheck` config object.
  FcheckConfig({
    required this.inputDirectory,
    required this.configDirectory,
    required this.sourceFile,
    required this.inputRoot,
    required this.excludePatterns,
    required this.analyzerDefaultEnabled,
    required this.enabledAnalyzers,
    required this.disabledAnalyzers,
    required this.duplicateCodeSimilarityThreshold,
    required this.duplicateCodeMinTokens,
    required this.duplicateCodeMinNonEmptyLines,
  });

  /// Loads `.fcheck` from [inputDirectory], or returns defaults when absent.
  static FcheckConfig loadForInputDirectory(Directory inputDirectory) {
    final configFile = File(p.join(inputDirectory.path, fileName));
    if (!configFile.existsSync()) {
      return FcheckConfig(
        inputDirectory: inputDirectory,
        configDirectory: inputDirectory,
        sourceFile: null,
        inputRoot: null,
        excludePatterns: const [],
        analyzerDefaultEnabled: true,
        enabledAnalyzers: {},
        disabledAnalyzers: {},
        duplicateCodeSimilarityThreshold:
            defaultDuplicateCodeSimilarityThreshold,
        duplicateCodeMinTokens: defaultDuplicateCodeMinTokens,
        duplicateCodeMinNonEmptyLines: defaultDuplicateCodeMinNonEmptyLines,
      );
    }

    final dynamic yaml;
    try {
      yaml = loadYaml(configFile.readAsStringSync());
    } catch (error) {
      throw FormatException('invalid YAML in ${configFile.path}: $error');
    }

    if (yaml == null) {
      return FcheckConfig(
        inputDirectory: inputDirectory,
        configDirectory: configFile.parent,
        sourceFile: configFile,
        inputRoot: null,
        excludePatterns: const [],
        analyzerDefaultEnabled: true,
        enabledAnalyzers: {},
        disabledAnalyzers: {},
        duplicateCodeSimilarityThreshold:
            defaultDuplicateCodeSimilarityThreshold,
        duplicateCodeMinTokens: defaultDuplicateCodeMinTokens,
        duplicateCodeMinNonEmptyLines: defaultDuplicateCodeMinNonEmptyLines,
      );
    }

    if (yaml is! YamlMap) {
      throw FormatException('`${configFile.path}` must contain a YAML map.');
    }

    final inputSection = _readMap(yaml, 'input', filePath: configFile.path);
    final analyzersSection =
        _readMap(yaml, 'analyzers', filePath: configFile.path);
    final ignoresSection = _readMap(yaml, 'ignores', filePath: configFile.path);

    final root = _readOptionalString(
      inputSection,
      'root',
      filePath: configFile.path,
      contextPath: 'input.root',
    );
    final exclude = _readStringList(
      inputSection,
      'exclude',
      filePath: configFile.path,
      contextPath: 'input.exclude',
    );

    final defaultEnabled = _readAnalyzerDefault(
      analyzersSection,
      filePath: configFile.path,
    );
    final enabled = _readAnalyzerSet(
      analyzersSection,
      'enabled',
      filePath: configFile.path,
    );
    final disabled = _readAnalyzerSet(
      analyzersSection,
      'disabled',
      filePath: configFile.path,
    );
    final duplicateCodeOptions = _readDuplicateCodeOptions(
      analyzersSection,
      filePath: configFile.path,
    );
    disabled
        .addAll(_readLegacyIgnores(ignoresSection, filePath: configFile.path));

    return FcheckConfig(
      inputDirectory: inputDirectory,
      configDirectory: configFile.parent,
      sourceFile: configFile,
      inputRoot: root,
      excludePatterns: List.unmodifiable(exclude),
      analyzerDefaultEnabled: defaultEnabled,
      enabledAnalyzers: Set.unmodifiable(enabled),
      disabledAnalyzers: Set.unmodifiable(disabled),
      duplicateCodeSimilarityThreshold:
          duplicateCodeOptions.similarityThreshold,
      duplicateCodeMinTokens: duplicateCodeOptions.minTokens,
      duplicateCodeMinNonEmptyLines: duplicateCodeOptions.minNonEmptyLines,
    );
  }

  /// Resolves the effective analysis directory using `input.root` when present.
  Directory resolveAnalysisDirectory() {
    final root = inputRoot?.trim();
    if (root == null || root.isEmpty || root == '.') {
      return inputDirectory;
    }
    final resolvedPath = p.normalize(p.join(configDirectory.path, root));
    return Directory(resolvedPath);
  }

  /// Returns merged exclude patterns with CLI patterns taking additive precedence.
  List<String> mergeExcludePatterns(List<String> cliExcludePatterns) {
    final merged = <String>[];
    final seen = <String>{};

    void addPatterns(Iterable<String> patterns) {
      for (final pattern in patterns) {
        final trimmed = pattern.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        if (seen.add(trimmed)) {
          merged.add(trimmed);
        }
      }
    }

    addPatterns(excludePatterns);
    addPatterns(cliExcludePatterns);
    return merged;
  }

  /// Computes effective analyzer set after applying defaults and overrides.
  Set<AnalyzerDomain> get effectiveEnabledAnalyzers {
    final effective = analyzerDefaultEnabled
        ? AnalyzerDomain.values.toSet()
        : <AnalyzerDomain>{};
    effective.addAll(enabledAnalyzers);
    effective.removeAll(disabledAnalyzers);
    return effective;
  }

  /// Reads an optional map at [key] and validates that the value is a map.
  static YamlMap? _readMap(
    YamlMap source,
    String key, {
    required String filePath,
  }) {
    return _readOptionalValueOfType<YamlMap>(
      source,
      key,
      filePath: filePath,
      contextPath: key,
      expectedTypeDescription: 'a map',
    );
  }

  /// Reads an optional string at [key], returning the trimmed value when set.
  static String? _readOptionalString(
    YamlMap? source,
    String key, {
    required String filePath,
    required String contextPath,
  }) {
    final value = _readOptionalValueOfType<String>(
      source,
      key,
      filePath: filePath,
      contextPath: contextPath,
      expectedTypeDescription: 'a string',
    );
    return value?.trim();
  }

  /// Reads a list of strings at [key], trimming entries and dropping empties.
  ///
  /// Throws a [FormatException] when the field is present but not a list of
  /// strings.
  static List<String> _readStringList(
    YamlMap? source,
    String key, {
    required String filePath,
    required String contextPath,
  }) {
    if (source == null) {
      return <String>[];
    }
    final value = source[key];
    if (value == null) {
      return <String>[];
    }
    if (value is! YamlList) {
      throw FormatException(
          '`$filePath` field `$contextPath` must be a list of strings.');
    }
    final values = <String>[];
    for (final entry in value) {
      if (entry is! String) {
        throw FormatException(
            '`$filePath` field `$contextPath` must contain only strings.');
      }
      final trimmed = entry.trim();
      if (trimmed.isNotEmpty) {
        values.add(trimmed);
      }
    }
    return values;
  }

  /// Reads `analyzers.default` and normalizes supported on/off values.
  ///
  /// Accepts bool values and string aliases (`on`/`off`, `true`/`false`).
  static bool _readAnalyzerDefault(
    YamlMap? analyzersSection, {
    required String filePath,
  }) {
    if (analyzersSection == null) {
      return true;
    }
    final value = analyzersSection['default'];
    if (value == null) {
      return true;
    }
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'on' || normalized == 'true') {
        return true;
      }
      if (normalized == 'off' || normalized == 'false') {
        return false;
      }
    }
    throw FormatException(
        '`$filePath` field `analyzers.default` must be `on`, `off`, true, or false.');
  }

  /// Reads an analyzer name list from `analyzers.[key]` and resolves domains.
  static Set<AnalyzerDomain> _readAnalyzerSet(
    YamlMap? analyzersSection,
    String key, {
    required String filePath,
  }) {
    if (analyzersSection == null) {
      return <AnalyzerDomain>{};
    }
    final value = analyzersSection[key];
    if (value == null) {
      return <AnalyzerDomain>{};
    }
    if (value is! YamlList) {
      throw FormatException(
          '`$filePath` field `analyzers.$key` must be a list of analyzer names.');
    }

    final analyzers = <AnalyzerDomain>{};
    for (final entry in value) {
      if (entry is! String) {
        throw FormatException(
            '`$filePath` field `analyzers.$key` must contain only strings.');
      }
      analyzers.add(
        _parseAnalyzer(entry,
            filePath: filePath, contextPath: 'analyzers.$key'),
      );
    }
    return analyzers;
  }

  /// Reads duplicate-code analyzer options with defaults and range checks.
  static _DuplicateCodeOptions _readDuplicateCodeOptions(
    YamlMap? analyzersSection, {
    required String filePath,
  }) {
    final optionsSection = _readNestedMap(
      analyzersSection,
      'options',
      filePath: filePath,
      contextPath: 'analyzers.options',
    );
    final duplicateCodeSection = _readNestedMap(
      optionsSection,
      'duplicate_code',
      filePath: filePath,
      contextPath: 'analyzers.options.duplicate_code',
    );

    final similarityThreshold = _readDoubleInRange(
      duplicateCodeSection,
      'similarity_threshold',
      filePath: filePath,
      contextPath: 'analyzers.options.duplicate_code.similarity_threshold',
      defaultValue: defaultDuplicateCodeSimilarityThreshold,
      min: 0,
      max: 1,
    );
    final minTokens = _readPositiveInt(
      duplicateCodeSection,
      'min_tokens',
      filePath: filePath,
      contextPath: 'analyzers.options.duplicate_code.min_tokens',
      defaultValue: defaultDuplicateCodeMinTokens,
    );
    final minNonEmptyLines = _readPositiveInt(
      duplicateCodeSection,
      'min_non_empty_lines',
      filePath: filePath,
      contextPath: 'analyzers.options.duplicate_code.min_non_empty_lines',
      defaultValue: defaultDuplicateCodeMinNonEmptyLines,
    );

    return _DuplicateCodeOptions(
      similarityThreshold: similarityThreshold,
      minTokens: minTokens,
      minNonEmptyLines: minNonEmptyLines,
    );
  }

  /// Reads an optional nested map at [key] from [source].
  static YamlMap? _readNestedMap(
    YamlMap? source,
    String key, {
    required String filePath,
    required String contextPath,
  }) {
    return _readOptionalValueOfType<YamlMap>(
      source,
      key,
      filePath: filePath,
      contextPath: contextPath,
      expectedTypeDescription: 'a map',
    );
  }

  /// Reads an optional value and validates that it matches [T] when present.
  ///
  /// Returns `null` when the source map or key is missing.
  static T? _readOptionalValueOfType<T>(
    YamlMap? source,
    String key, {
    required String filePath,
    required String contextPath,
    required String expectedTypeDescription,
  }) {
    if (source == null) {
      return null;
    }
    final value = source[key];
    if (value == null) {
      return null;
    }
    if (value is T) {
      return value;
    }
    throw FormatException(
      '`$filePath` field `$contextPath` must be $expectedTypeDescription.',
    );
  }

  /// Reads an optional numeric value in the inclusive range `[min, max]`.
  ///
  /// Returns [defaultValue] when the field is missing.
  static double _readDoubleInRange(
    YamlMap? source,
    String key, {
    required String filePath,
    required String contextPath,
    required double defaultValue,
    required double min,
    required double max,
  }) {
    if (source == null) {
      return defaultValue;
    }
    final value = source[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is! num) {
      throw FormatException(
          '`$filePath` field `$contextPath` must be a number.');
    }
    final parsed = value.toDouble();
    if (parsed < min || parsed > max) {
      throw FormatException(
        '`$filePath` field `$contextPath` must be between $min and $max.',
      );
    }
    return parsed;
  }

  /// Reads an optional positive integer, falling back to [defaultValue].
  static int _readPositiveInt(
    YamlMap? source,
    String key, {
    required String filePath,
    required String contextPath,
    required int defaultValue,
  }) {
    if (source == null) {
      return defaultValue;
    }
    final value = source[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is! int || value <= 0) {
      throw FormatException(
        '`$filePath` field `$contextPath` must be a positive integer.',
      );
    }
    return value;
  }

  /// Reads legacy `ignores` booleans and converts enabled flags to domains.
  ///
  /// A `true` value means the corresponding analyzer is disabled.
  static Set<AnalyzerDomain> _readLegacyIgnores(
    YamlMap? ignoresSection, {
    required String filePath,
  }) {
    if (ignoresSection == null) {
      return <AnalyzerDomain>{};
    }

    final disabled = <AnalyzerDomain>{};
    for (final entry in ignoresSection.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String) {
        throw FormatException(
            '`$filePath` field `ignores` must use string keys.');
      }
      if (value is! bool) {
        throw FormatException(
            '`$filePath` field `ignores.$key` must be a boolean.');
      }
      if (value) {
        disabled.add(
          _parseAnalyzer(key, filePath: filePath, contextPath: 'ignores.$key'),
        );
      }
    }
    return disabled;
  }

  /// Resolves an analyzer name or alias into an [AnalyzerDomain].
  ///
  /// Normalization trims, lowercases, and converts dashes/spaces to `_`.
  static AnalyzerDomain _parseAnalyzer(
    String rawName, {
    required String filePath,
    required String contextPath,
  }) {
    final normalized = rawName
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '_');

    final analyzer = _analyzerAliases[normalized];
    if (analyzer != null) {
      return analyzer;
    }

    final allowed = AnalyzerDomain.values.map((a) => a.configName).join(', ');
    throw FormatException(
      '`$filePath` field `$contextPath` references unknown analyzer "$rawName". '
      'Allowed values: $allowed',
    );
  }

  static final Map<String, AnalyzerDomain> _analyzerAliases = {
    'one_class_per_file': AnalyzerDomain.oneClassPerFile,
    'hardcoded_strings': AnalyzerDomain.hardcodedStrings,
    'magic_numbers': AnalyzerDomain.magicNumbers,
    'source_sorting': AnalyzerDomain.sourceSorting,
    'sorting': AnalyzerDomain.sourceSorting,
    'layers': AnalyzerDomain.layers,
    'secrets': AnalyzerDomain.secrets,
    'dead_code': AnalyzerDomain.deadCode,
    'duplicate_code': AnalyzerDomain.duplicateCode,
    'documentation': AnalyzerDomain.documentation,
  };
}

class _DuplicateCodeOptions {
  final double similarityThreshold;
  final int minTokens;
  final int minNonEmptyLines;

  const _DuplicateCodeOptions({
    required this.similarityThreshold,
    required this.minTokens,
    required this.minNonEmptyLines,
  });
}
