import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'hardcoded_string_issue.dart';
import 'hardcoded_string_utils.dart';
import '../../models/ignore_config.dart';

/// Focus modes for hardcoded string detection.
enum HardcodedStringFocus {
  /// Current behavior: detect general hardcoded strings based on skip rules.
  general,

  /// Flutter mode: focus on widget output strings and ignore print/logger output.
  flutterWidgets,

  /// Dart mode: focus on print output and ignore logger/debug output.
  dartPrint,
}

/// A visitor that traverses the AST to detect hardcoded strings.
///
/// This class extends the analyzer's AST visitor to identify string literals
/// in Dart source code that may represent user-facing content that should be
/// localized. It intelligently filters out strings that are legitimately
/// hardcoded (imports, annotations, const declarations, etc.).
class HardcodedStringVisitor extends GeneralizingAstVisitor<void> {
  static const int _maxShortWidgetStringLength = 2;
  static const int _previousLineOffset = 2;
  static const int _tripleQuoteLength = 3;

  /// Creates a new visitor for the specified file.
  ///
  /// [filePath] should be the path to the file being analyzed.
  /// [content] should be the full text content of the file.
  HardcodedStringVisitor(
    this.filePath,
    this.content, {
    this.focus = HardcodedStringFocus.general,
  });

  /// The file path being analyzed.
  final String filePath;

  /// The full text content of the file.
  final String content;

  /// The list of hardcoded string issues found during traversal.
  final List<HardcodedStringIssue> foundIssues = <HardcodedStringIssue>[];

  /// Which focus mode is applied for hardcoded string detection.
  final HardcodedStringFocus focus;

  /// Visits a simple string literal node in the AST.
  ///
  /// This method is called for each simple string literal encountered during
  /// AST traversal. It analyzes the string to determine if it represents a
  /// potentially hardcoded user-facing string that should be localized.
  /// Various heuristics are used to filter out legitimate hardcoded strings
  /// such as imports, annotations, const declarations, etc.
  ///
  /// [node] The simple string literal node being visited.
  @override
  void visitSimpleStringLiteral(final SimpleStringLiteral node) {
    // Focus filter (Flutter widgets vs Dart print).
    if (!_matchesFocus(node)) {
      return;
    }

    // Skip empty strings
    if (node.value.isEmpty) {
      return;
    }

    // Flutter-only additional filters.
    if (focus == HardcodedStringFocus.flutterWidgets) {
      if (_isInterpolationOnlyLiteral(node)) {
        return;
      }

      if (_hasWidgetLintIgnoreComment(node)) {
        return;
      }

      if (node.value.length <= _maxShortWidgetStringLength) {
        return;
      }

      if (_isAcceptableWidgetProperty(node)) {
        return;
      }

      if (_isTechnicalString(node.value)) {
        return;
      }
    }

    // Skip strings that are in import/part/library directives
    if (_isInDirective(node)) {
      return;
    }

    // Skip strings in annotations
    if (_isInAnnotation(node)) {
      return;
    }

    // Skip strings that are keys in Map literals (common for const maps)
    if (_isMapKey(node)) {
      return;
    }

    // Skip strings in const declarations
    if (_isInConstDeclaration(node)) {
      return;
    }

    // Skip strings in l10n calls (basic detection)
    if (_isInL10nCall(node)) {
      return;
    }

    // Skip strings in RegExp calls
    if (_isInRegExpCall(node)) {
      return;
    }

    // Skip strings in Key constructors
    if (_isInKey(node)) {
      return;
    }

    // Skip strings used as index in collections/maps
    if (_isIndex(node)) {
      return;
    }

    // Skip strings in ignored sections
    if (IgnoreConfig.isNodeIgnored(node, content, 'hardcoded_strings')) {
      return;
    }

    // Get line number
    final int lineNumber = _getLineNumber(node.offset);

    foundIssues.add(HardcodedStringIssue(
      filePath: filePath,
      lineNumber: lineNumber,
      value: node.value,
    ));
  }

  bool _matchesFocus(final StringLiteral node) {
    switch (focus) {
      case HardcodedStringFocus.general:
        return true;
      case HardcodedStringFocus.flutterWidgets:
        if (_isInPrintOrLoggerCall(node)) {
          return false;
        }
        return _isWidgetOutputString(node);
      case HardcodedStringFocus.dartPrint:
        return _isInPrintCall(node);
    }
  }

  /// Checks if a string literal is within a directive (import/export/part).
  bool _isInDirective(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ImportDirective ||
          current is ExportDirective ||
          current is PartDirective ||
          current is PartOfDirective ||
          current is LibraryDirective) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isWidgetOutputString(final StringLiteral node) {
    final ArgumentList? argumentList =
        node.thisOrAncestorOfType<ArgumentList>();
    if (argumentList == null) {
      return false;
    }

    if (!_isDirectArgument(node, argumentList)) {
      return false;
    }

    if (_hasFunctionBoundary(node, argumentList)) {
      return false;
    }

    final owner = argumentList.parent;
    if (owner is! InstanceCreationExpression) {
      return false;
    }

    if (_isInsideWidgetClass(node)) {
      return true;
    }

    if (_isInsideBuildMethod(node)) {
      return true;
    }

    return _isInsideWidgetReturnFunction(node);
  }

  bool _hasWidgetLintIgnoreComment(final StringLiteral node) {
    final int lineNumber = _getLineNumber(node.offset);
    final List<String> lines = content.split('\n');

    if (lineNumber > 0 && lineNumber <= lines.length) {
      final String currentLine = lines[lineNumber - 1];
      if (_containsWidgetLintIgnoreComment(currentLine)) {
        return true;
      }

      if (lineNumber > 1) {
        final String previousLine = lines[lineNumber - _previousLineOffset];
        if (_containsWidgetLintIgnoreComment(previousLine)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isInterpolationOnlyLiteral(final StringLiteral node) {
    final String source = node.toSource();
    final (content, isRaw) = _stripLiteralDelimiters(source);
    if (isRaw) {
      return false;
    }

    final String withoutInterpolations =
        HardcodedStringUtils.removeInterpolations(content);
    return !HardcodedStringUtils.containsMeaningfulText(withoutInterpolations);
  }

  (String content, bool isRaw) _stripLiteralDelimiters(String source) {
    var working = source;
    var isRaw = false;

    if (working.startsWith('r') || working.startsWith('R')) {
      isRaw = true;
      working = working.substring(1);
    }

    if (working.startsWith("'''") || working.startsWith('"""')) {
      if (working.length >=
          _tripleQuoteLength * HardcodedStringUtils.minQuotedLength) {
        return (
          working.substring(
            _tripleQuoteLength,
            working.length - _tripleQuoteLength,
          ),
          isRaw,
        );
      }
      return ('', isRaw);
    }

    if (working.length >= HardcodedStringUtils.minQuotedLength) {
      return (working.substring(1, working.length - 1), isRaw);
    }

    return ('', isRaw);
  }

  bool _containsWidgetLintIgnoreComment(final String line) {
    final ignorePatterns = [
      RegExp(r'//\s*ignore:\s*avoid_hardcoded_strings_in_widgets'),
      RegExp(r'//\s*ignore_for_file:\s*avoid_hardcoded_strings_in_widgets'),
      RegExp(r'//\s*ignore:\s*hardcoded.string', caseSensitive: false),
      RegExp(r'//\s*hardcoded.ok', caseSensitive: false),
    ];

    return ignorePatterns.any((pattern) => pattern.hasMatch(line));
  }

  bool _isAcceptableWidgetProperty(final StringLiteral node) {
    final AstNode? parent = node.parent;
    if (parent is! NamedExpression) {
      return false;
    }

    final String propertyName = parent.name.label.name;

    const acceptableProperties = {
      'semanticsLabel',
      'excludeSemantics',
      'restorationId',
      'heroTag',
      'key',
      'debugLabel',
      'fontFamily',
      'package',
      'name',
      'asset',
      'tooltip',
      'textDirection',
      'locale',
      'materialType',
      'clipBehavior',
      'crossAxisAlignment',
      'mainAxisAlignment',
      'textAlign',
      'textBaseline',
      'overflow',
      'softWrap',
      'textScaleFactor',
    };

    return acceptableProperties.contains(propertyName);
  }

  bool _isTechnicalString(final String value) {
    return HardcodedStringUtils.isTechnicalString(value);
  }

  bool _isDirectArgument(
    final StringLiteral node,
    final ArgumentList argumentList,
  ) {
    for (final arg in argumentList.arguments) {
      if (identical(arg, node)) {
        return true;
      }
      if (arg is NamedExpression && identical(arg.expression, node)) {
        return true;
      }
    }
    return false;
  }

  bool _hasFunctionBoundary(
    final StringLiteral node,
    final ArgumentList argumentList,
  ) {
    AstNode? walker = node.parent;
    while (walker != null && walker != argumentList) {
      if (walker is FunctionExpression || walker is FunctionBody) {
        return true;
      }
      walker = walker.parent;
    }
    return false;
  }

  bool _isInsideWidgetClass(final AstNode node) {
    final ClassDeclaration? classDecl =
        node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) {
      return false;
    }
    final extendsClause = classDecl.extendsClause;
    if (extendsClause == null) {
      return false;
    }

    final String superName = extendsClause.superclass.toString();
    return superName == 'StatelessWidget' ||
        superName == 'StatefulWidget' ||
        superName == 'State' ||
        superName.startsWith('State<');
  }

  bool _isInsideBuildMethod(final AstNode node) {
    final MethodDeclaration? method =
        node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) {
      return false;
    }

    if (method.name.lexeme == 'build') {
      return true;
    }

    return _isWidgetReturnType(method.returnType);
  }

  bool _isInsideWidgetReturnFunction(final AstNode node) {
    final FunctionDeclaration? function =
        node.thisOrAncestorOfType<FunctionDeclaration>();
    if (function == null) {
      return false;
    }

    if (function.name.lexeme == 'build') {
      return true;
    }

    return _isWidgetReturnType(function.returnType);
  }

  bool _isWidgetReturnType(final TypeAnnotation? type) {
    if (type == null) {
      return false;
    }
    final String typeName = type.toString();
    return typeName.contains('Widget');
  }

  /// Checks if a string literal is within an annotation.
  bool _isInAnnotation(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Annotation) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is used as a key in a map literal.
  bool _isMapKey(final AstNode node) {
    final AstNode? parent = node.parent;
    if (parent is MapLiteralEntry) {
      return parent.key == node;
    }
    return false;
  }

  /// Checks if a string literal is within a const declaration.
  bool _isInConstDeclaration(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is VariableDeclaration) {
        final VariableDeclaration varDecl = current;
        if (varDecl.parent is VariableDeclarationList) {
          final VariableDeclarationList varList =
              varDecl.parent as VariableDeclarationList;
          if (varList.isConst) {
            return true;
          }
        }
      } else if (current is FieldDeclaration && current.fields.isConst) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is within an AppLocalizations call.
  bool _isInL10nCall(final AstNode node) {
    // Basic detection for AppLocalizations calls
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final MethodInvocation invocation = current;
        final Expression? target = invocation.target;
        if (target != null && target.toString().contains('AppLocalizations')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is within a RegExp constructor or call.
  bool _isInRegExpCall(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final MethodInvocation invocation = current;
        if (invocation.methodName.name == 'RegExp') {
          return true;
        }
      } else if (current is InstanceCreationExpression) {
        final InstanceCreationExpression creation = current;
        if (creation.constructorName.name?.name == 'RegExp') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is within a Key constructor.
  bool _isInKey(final AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is NamedExpression) {
        if (current.name.label.name == 'key') {
          return true;
        }
      }
      if (current is InstanceCreationExpression) {
        final String rawTypeName = current.constructorName.type.toString();
        final String typeName = rawTypeName.split('.').last;
        if (typeName == 'Key' ||
            typeName == 'ValueKey' ||
            typeName == 'ObjectKey') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Checks if a string literal is used as an index in a collection.
  bool _isIndex(final AstNode node) {
    final AstNode? parent = node.parent;
    if (parent is IndexExpression) {
      return parent.index == node;
    }
    return false;
  }

  bool _isInPrintCall(final StringLiteral node) {
    final MethodInvocation? invocation = _getOwningMethodInvocation(node);
    if (invocation == null) {
      return false;
    }

    return invocation.methodName.name == 'print' && invocation.target == null;
  }

  bool _isInPrintOrLoggerCall(final StringLiteral node) {
    final MethodInvocation? invocation = _getOwningMethodInvocation(node);
    if (invocation == null) {
      return false;
    }

    final String methodName = invocation.methodName.name;
    final String targetName = _getInvocationTargetName(invocation);

    const printNames = {
      'print',
      'debugPrint',
      'debugPrintStack',
    };

    if (printNames.contains(methodName)) {
      return true;
    }

    const loggerMethodNames = {
      'log',
      'logger',
      'info',
      'debug',
      'warn',
      'warning',
      'error',
      'trace',
      'fatal',
      'wtf',
    };

    if (loggerMethodNames.contains(methodName)) {
      return true;
    }

    if (targetName.isEmpty) {
      return false;
    }

    final targetLower = targetName.toLowerCase();
    return targetLower.contains('logger') || targetLower.contains('log');
  }

  MethodInvocation? _getOwningMethodInvocation(final StringLiteral node) {
    final ArgumentList? argumentList =
        node.thisOrAncestorOfType<ArgumentList>();
    if (argumentList == null) {
      return null;
    }

    if (!_isDirectArgument(node, argumentList)) {
      return null;
    }

    if (_hasFunctionBoundary(node, argumentList)) {
      return null;
    }

    final owner = argumentList.parent;
    return owner is MethodInvocation ? owner : null;
  }

  String _getInvocationTargetName(final MethodInvocation invocation) {
    final Expression? target = invocation.target;
    if (target == null) {
      return '';
    }
    if (target is SimpleIdentifier) {
      return target.name;
    }
    return target.toString();
  }

  /// Calculates the 1-based line number for a given character offset.
  int _getLineNumber(final int offset) {
    final List<String> lines = content.substring(0, offset).split('\n');
    return lines.length;
  }
}
