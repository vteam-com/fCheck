/// Whether a project's generated localizations class matches its ARB
/// files, as `flutter gen-l10n` would write it.
///
/// A class edited by hand, or written without ARB files, loses keys and
/// code the next time gen-l10n runs.
class LocalizationSync {
  /// Creates the comparison of [generatedFilePath] with [templateArbPath].
  const LocalizationSync({
    required this.generatedFilePath,
    required this.templateArbPath,
    required this.outputClass,
    this.generatedOnlyKeys = const [],
    this.handWrittenMembers = const [],
    this.missingKeys = const [],
  });

  /// Absolute path of the generated localizations class.
  final String generatedFilePath;

  /// Keys the generated class declares that the template ARB file lacks.
  final List<String> generatedOnlyKeys;

  /// Code in the generated file that gen-l10n does not write, such as
  /// `extension AppLocalizationsExtension`, a static method's name or an
  /// instance member other than a key's abstract `String` getter or method.
  final List<String> handWrittenMembers;

  /// Keys of the template ARB file the generated class lacks, as when the
  /// class is older than the ARB file.
  final List<String> missingKeys;

  /// Name of the generated class.
  final String outputClass;

  /// Absolute path of the template ARB file.
  final String templateArbPath;

  /// Whether the class declares exactly the template ARB file's keys and
  /// nothing gen-l10n would not write.
  bool get isInSync =>
      generatedOnlyKeys.isEmpty &&
      missingKeys.isEmpty &&
      handWrittenMembers.isEmpty;

  /// Converts this comparison to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'path': generatedFilePath,
    'templateArb': templateArbPath,
    'isInSync': isInSync,
    'generatedOnlyKeys': generatedOnlyKeys,
    'missingKeys': missingKeys,
    'handWrittenMembers': handWrittenMembers,
  };
}
