import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fcheck/src/analyzers/localization/localization_config.dart';
import 'package:fcheck/src/analyzers/localization/localization_sync.dart';
import 'package:path/path.dart' as p;

/// Compares a project's generated localizations class with its template
/// ARB file.
class LocalizationSyncChecker {
  /// Creates a stateless checker.
  const LocalizationSyncChecker();

  /// Static members gen-l10n writes into the localizations class.
  static const Set<String> _generatedStatics = {
    'delegate',
    'localizationsDelegates',
    'of',
    'supportedLocales',
  };

  /// The instance field gen-l10n writes into the localizations class.
  static const String _localeNameField = 'localeName';

  /// The comparison for the project in [projectDir]; null when it has no
  /// generated file declaring the class or no template ARB file to
  /// compare, or generates into the synthetic `flutter_gen` package.
  LocalizationSync? check(Directory projectDir) {
    final config = LocalizationConfig.load(projectDir);
    if (config.syntheticPackage) {
      return null;
    }
    final generated = File(
      p.join(
        projectDir.path,
        config.outputDir ?? config.arbDir,
        config.outputFile,
      ),
    );
    final template = File(
      p.join(projectDir.path, config.arbDir, config.templateArbFile),
    );
    if (!generated.existsSync() || !template.existsSync()) {
      return null;
    }
    final Set<String> arbKeys = _arbKeys(template);
    final unit = parseString(
      content: generated.readAsStringSync(),
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    ).unit;

    final ClassDeclaration? generatedClass = unit.declarations
        .whereType<ClassDeclaration>()
        .where((c) => c.namePart.typeName.lexeme == config.outputClass)
        .firstOrNull;
    if (generatedClass == null) {
      return null;
    }

    final generatedKeys = <String>{};
    final handWrittenMembers = <String>[];
    for (final member in generatedClass.body.members) {
      switch (member) {
        case MethodDeclaration(:final name, :final isStatic)
            when isStatic && !_generatedStatics.contains(name.lexeme):
          handWrittenMembers.add(name.lexeme);
        case MethodDeclaration(:final name, :final isStatic, :final returnType)
            when !isStatic:
          // gen-l10n declares every key as an abstract String member
          if (member.body is EmptyFunctionBody &&
              returnType?.toSource() == 'String') {
            generatedKeys.add(name.lexeme);
          } else {
            handWrittenMembers.add(name.lexeme);
          }
        case FieldDeclaration(:final fields, :final isStatic):
          for (final variable in fields.variables) {
            final String name = variable.name.lexeme;
            final bool isGenerated = isStatic
                ? _generatedStatics.contains(name)
                : name == _localeNameField;
            if (!isGenerated) {
              handWrittenMembers.add(name);
            }
          }
        case ConstructorDeclaration(:final name?):
          handWrittenMembers.add('${config.outputClass}.${name.lexeme}');
        default:
          break;
      }
    }

    final generatedNames = {
      config.outputClass,
      '_${config.outputClass}Delegate',
      'lookup${config.outputClass}',
    };
    for (final declaration in unit.declarations) {
      if (declaration is ExtensionDeclaration) {
        handWrittenMembers.add('extension ${declaration.name?.lexeme ?? ''}');
      } else if (!generatedNames.contains(_nameOf(declaration))) {
        handWrittenMembers.add(_nameOf(declaration) ?? declaration.toSource());
      }
    }
    return LocalizationSync(
      generatedFilePath: generated.path,
      templateArbPath: template.path,
      outputClass: config.outputClass,
      generatedOnlyKeys: [
        for (final key in generatedKeys)
          if (!arbKeys.contains(key)) key,
      ],
      missingKeys: [
        for (final key in arbKeys)
          if (!generatedKeys.contains(key)) key,
      ],
      handWrittenMembers: handWrittenMembers,
    );
  }

  /// Translation keys of the ARB file [template]; empty when unreadable.
  Set<String> _arbKeys(File template) {
    try {
      final Object? json = jsonDecode(template.readAsStringSync());
      if (json is! Map<String, dynamic>) {
        return {};
      }
      return json.keys.where((key) => !key.startsWith('@')).toSet();
    } on FormatException {
      return {};
    }
  }

  /// The declared name of a top-level [declaration], if it has one.
  String? _nameOf(CompilationUnitMember declaration) => switch (declaration) {
    ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
    FunctionDeclaration(:final name) => name.lexeme,
    MixinDeclaration(:final name) => name.lexeme,
    EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
    TopLevelVariableDeclaration(:final variables) =>
      variables.variables.first.name.lexeme,
    _ => null,
  };
}
