import 'package:fcheck/src/analyzer_runner/analysis_file_context.dart';
import 'package:fcheck/src/analyzer_runner/analyzer_delegate_abstract.dart';
import 'package:fcheck/src/analyzers/shared/generated_file_utils.dart';
import 'package:fcheck/src/analyzers/widget_state/widget_state_file_data.dart';
import 'package:fcheck/src/analyzers/widget_state/widget_state_visitor.dart';
import 'package:fcheck/src/models/ignore_config.dart';
import 'package:path/path.dart' as p;

/// Delegate adapter collecting each file's widget `State` data, which
/// `WidgetStateAnalyzer` then judges across the project.
class WidgetStateDelegate implements AnalyzerDelegate {
  /// The domain name `// ignore: fcheck_widget_state` comments use.
  static const String ignoreDomain = 'widget_state';

  /// Collects the widget `State` data of one file; null for generated
  /// code, which no one fixes by hand.
  @override
  WidgetStateFileData? analyzeFileWithContext(AnalysisFileContext context) {
    // Absolute and normalized, as the part paths it is matched with
    final filePath = p.normalize(context.file.absolute.path);
    final unit = context.compilationUnit;
    if (unit == null ||
        isGeneratedDartFilePath(filePath) ||
        isGeneratedLocalizationDartFilePath(filePath)) {
      return null;
    }
    final visitor = WidgetStateVisitor(
      filePath: filePath,
      lineNumberForOffset: context.getLineNumber,
      ignoredLineNumbers: IgnoreConfig.collectIgnoredLineNumbers(
        context.lines,
        ignoreDomain,
      ),
    );
    unit.accept(visitor);
    return WidgetStateFileData(
      filePath: filePath,
      isIgnored: context.hasIgnoreForFileDirective(
        IgnoreConfig.ignoreDirectiveForWidgetState,
      ),
      partPaths: visitor.partPaths,
      classes: visitor.classes,
      typeUses: visitor.typeUses,
      stateMakers: visitor.stateMakers,
    );
  }
}
