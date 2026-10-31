import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fcheck/src/analyzers/hardcoded_strings/hardcoded_string_role.dart';

/// Parameters, variables and returns followed before a use is unknown.
const int _maxTraceDepth = 3;

/// Separator between the steps of a role's evidence.
const String _step = ' → ';

/// A string's role and the use that decided it, such as
/// `photoType → l10n.onlyDeleteOwnPhotos(…)`.
typedef HardcodedStringVerdict = ({HardcodedStringRole role, String evidence});

/// Judges the [HardcodedStringRole] of strings in one file by following
/// each string to where it is used: through parentheses, `?:`, `??`,
/// `+`, `.toLowerCase()`-like calls and switch expressions, and into the
/// file's own parameters, variables, fields and returned values.
///
/// The file is parsed without types, so uses are matched by name; a use
/// in another file is unknown.
class HardcodedStringRoleClassifier {
  /// Indexes the declarations and references of [unit].
  HardcodedStringRoleClassifier(CompilationUnit unit) {
    unit.accept(_DeclarationIndexer(this));
  }

  /// Methods and constructors whose string arguments the code compares or
  /// looks up: string matching, maps, Firestore, storage, preferences,
  /// navigation, parsing, assets and platform channels.
  static const Set<String> _dataCallees = {
    'AssetImage',
    'DateFormat',
    'Directory',
    'EventChannel',
    'FieldPath',
    'File',
    'Locale',
    'MethodChannel',
    'NetworkImage',
    'NumberFormat',
    'RouteSettings',
    'Uri',
    'allMatches',
    'asset',
    'byName',
    'child',
    'collection',
    'compareTo',
    'contains',
    'containsKey',
    'containsValue',
    'doc',
    'endsWith',
    'firstMatch',
    'getBool',
    'getDouble',
    'getInt',
    'getString',
    'getStringList',
    'go',
    'goNamed',
    'hasMatch',
    'httpsCallable',
    'indexOf',
    'invokeMethod',
    'lastIndexOf',
    'logEvent',
    'matchAsPrefix',
    'network',
    'orderBy',
    'parse',
    'popAndPushNamed',
    'pushNamed',
    'pushNamedAndRemoveUntil',
    'pushReplacementNamed',
    'ref',
    'remove',
    'replaceAll',
    'replaceFirst',
    'restorablePushNamed',
    'setBool',
    'setDouble',
    'setInt',
    'setString',
    'setStringList',
    'split',
    'startsWith',
    'tryParse',
    'where',
  };

  /// Named arguments holding identifiers or values the code matches,
  /// besides those ending in a [_dataWords] word.
  static const Set<String> _dataArguments = {
    'asset',
    'channel',
    'event',
    'groupValue',
    'host',
    'icon',
    'routeName',
    'scheme',
    'topic',
    'value',
  };

  /// Last words of names holding identifiers, such as `userId`, `prefKey`
  /// or `contentType`.
  static const Set<String> _dataWords = {
    'collection',
    'field',
    'id',
    'key',
    'path',
    'route',
    'tag',
    'type',
    'uri',
    'url',
  };

  /// Constructors showing their positional string argument.
  static const Set<String> _presentationCallees = {
    'SelectableText',
    'Text',
    'TextSpan',
    'Tooltip',
  };

  /// Named arguments holding text users read, besides those ending in a
  /// [_presentationWords] word.
  static const Set<String> _presentationArguments = {'body', 'content'};

  /// Last words of names holding text users read, such as `labelText`,
  /// `searchHint` or `errorMessage`.
  static const Set<String> _presentationWords = {
    'caption',
    'description',
    'heading',
    'hint',
    'label',
    'message',
    'placeholder',
    'subtitle',
    'text',
    'title',
    'tooltip',
  };

  /// Splits camelCase names before each capital.
  static final RegExp _wordStart = RegExp('(?=[A-Z])');

  /// Calls returning the text they are called on, changed but still the
  /// same text.
  static const Set<String> _textCalls = {
    'toLowerCase',
    'toString',
    'toUpperCase',
    'trim',
    'trimLeft',
    'trimRight',
  };

  /// Receivers of localized message lookups: `context.l10n`,
  /// `AppLocalizations.of(context)!`, `S.of(context)` or `S.current`.
  static final RegExp _localizationTarget = RegExp(
    r'(^|\.)l10n$|AppLocalizations|^S\.(of\(|current)',
  );

  /// Roles from the most to the least decisive: a string the code
  /// compares anywhere must stay as is, even if it is also shown.
  static const List<HardcodedStringRole> _precedence = [
    HardcodedStringRole.data,
    HardcodedStringRole.presentation,
    HardcodedStringRole.fragment,
    HardcodedStringRole.unknown,
  ];

  /// Methods, functions and constructors of the file by name, constructors
  /// as `Class` or `Class.name`.
  final Map<String, List<_Callable>> _callables = {};

  /// Identifiers referencing a value, by name.
  final Map<String, List<SimpleIdentifier>> _references = {};

  /// Method calls, by method name.
  final Map<String, List<MethodInvocation>> _invocations = {};

  /// The role of [string], from its uses.
  HardcodedStringVerdict classify(Expression string) =>
      _useOf(string, 0, <AstNode>{});

  /// The role [expression]'s value has where it is used, [depth] steps
  /// into the file's declarations, not entering those in [visiting].
  HardcodedStringVerdict _useOf(
    Expression expression,
    int depth,
    Set<AstNode> visiting,
  ) {
    final Expression value = _passedThrough(expression);
    final AstNode? parent = value.parent;
    return switch (parent) {
      NamedArgument(:final name, :final parent) when parent is ArgumentList =>
        _argument(parent, name.lexeme, -1, depth, visiting),
      ArgumentList(:final arguments) => _argument(
        parent,
        null,
        arguments.whereType<Expression>().toList().indexOf(value),
        depth,
        visiting,
      ),
      BinaryExpression(:final leftOperand, :final rightOperand)
          when leftOperand is NullLiteral || rightOperand is NullLiteral =>
        _unknown('null check'),
      BinaryExpression(:final operator) => _verdict(
        HardcodedStringRole.data,
        '${operator.lexeme} comparison',
      ),
      ConstantPattern() ||
      SwitchCase() => _verdict(HardcodedStringRole.data, 'switch case'),
      SwitchStatement() ||
      SwitchExpression() => _verdict(HardcodedStringRole.data, 'switched on'),
      IndexExpression(:final index) when identical(index, value) => _verdict(
        HardcodedStringRole.data,
        '[…] key',
      ),
      MapLiteralEntry(:final key) when identical(key, value) => _verdict(
        HardcodedStringRole.data,
        'map key',
      ),
      MethodInvocation(:final methodName) =>
        _dataCallees.contains(methodName.name)
            ? _verdict(HardcodedStringRole.data, '.${methodName.name}(…)')
            : _unknown('.${methodName.name}(…)'),
      InterpolationExpression() => _verdict(
        HardcodedStringRole.fragment,
        'inside another string',
      ),
      ReturnStatement() ||
      ExpressionFunctionBody() => _returned(value, depth, visiting),
      VariableDeclaration(:final name, :final parent) => _variable(
        name.lexeme,
        parent,
        depth,
        visiting,
      ),
      AssignmentExpression(:final leftHandSide) => _assigned(
        leftHandSide,
        depth,
        visiting,
      ),
      ConstructorFieldInitializer(:final fieldName) => _member(
        fieldName.name,
        parent,
        depth,
        visiting,
      ),
      FormalParameterDefaultClause(:final parent)
          when parent is FormalParameter =>
        _defaulted(parent, depth, visiting),
      Assertion() => _unknown('assert message'),
      _ => _unknown(''),
    };
  }

  /// The outermost expression still holding [expression]'s text: through
  /// parentheses, `?:` branches, `??`, `+`, `!`, `as`, `await`, text calls
  /// such as `.toLowerCase()`, switch expression cases, and the list, set
  /// or map (as a value) it is an element of.
  Expression _passedThrough(Expression expression) {
    Expression current = expression;
    while (true) {
      final AstNode? parent = current.parent;
      final Expression? outer = switch (parent) {
        ParenthesizedExpression() ||
        PostfixExpression() ||
        AsExpression() ||
        AwaitExpression() => parent as Expression,
        ConditionalExpression(:final condition)
            when !identical(condition, current) =>
          parent,
        BinaryExpression(:final operator)
            when operator.lexeme == '??' || operator.lexeme == '+' =>
          parent,
        MethodInvocation(:final target, :final methodName)
            when identical(target, current) &&
                _textCalls.contains(methodName.name) =>
          parent,
        SwitchExpressionCase(:final parent) when parent is SwitchExpression =>
          parent,
        MapLiteralEntry(:final value, :final parent)
            when identical(value, current) && parent is SetOrMapLiteral =>
          parent,
        ListLiteral() || SetOrMapLiteral() => parent as Expression,
        _ => null,
      };
      if (outer == null) return current;
      current = outer;
    }
  }

  /// The role of a value passed in [arguments] as [name], or positional
  /// at [index].
  HardcodedStringVerdict _argument(
    ArgumentList arguments,
    String? name,
    int index,
    int depth,
    Set<AstNode> visiting,
  ) {
    final (
      String? callee,
      String? receiver,
      String? className,
    ) = switch (arguments.parent) {
      InstanceCreationExpression(:final constructorName) => (
        constructorName.type.toSource().split('<').first.split('.').last,
        constructorName.name?.name,
        constructorName.type.toSource().split('<').first.split('.').last,
      ),
      MethodInvocation(:final methodName, :final target) => (
        methodName.name,
        target?.toSource(),
        null,
      ),
      _ => (null, null, null),
    };
    if (callee == null) return _unknown('called function');
    final bool isConstructor =
        className != null || callee.startsWith(RegExp('[A-Z]'));
    final String call = receiver == null || isConstructor ? callee : '.$callee';
    final HardcodedStringRole? named = name == null ? null : _roleOfName(name);
    final String use = name == null ? '$call(…)' : '$call($name:)';
    if (receiver != null && _localizationTarget.hasMatch(receiver)) {
      return _verdict(HardcodedStringRole.fragment, 'l10n.$callee(…)');
    }
    if (_dataCallees.contains(callee) || _dataCallees.contains(receiver)) {
      return _verdict(HardcodedStringRole.data, use);
    }
    if (name == null && _presentationCallees.contains(callee)) {
      return _verdict(HardcodedStringRole.presentation, use);
    }
    final String key = className != null
        ? receiver == null
              ? className
              : '$className.$receiver'
        : receiver != null && receiver.startsWith(_wordStart)
        ? '$receiver.$callee'
        : callee;
    for (final callable in _callables[key] ?? const <_Callable>[]) {
      final FormalParameter? parameter = callable.parameter(name, index);
      if (parameter != null && !visiting.contains(callable.node)) {
        final verdict = _parameter(parameter, callable, depth, {
          ...visiting,
          callable.node,
        });
        if (verdict.role != HardcodedStringRole.unknown) return verdict;
      }
    }
    // Declared elsewhere or undecided: the argument's name tells
    if (named != null) return _verdict(named, use);
    if (name == null && isConstructor) {
      return _verdict(HardcodedStringRole.presentation, use);
    }
    return _unknown(use);
  }

  /// The role of a value passed as [parameter] of [callable].
  HardcodedStringVerdict _parameter(
    FormalParameter parameter,
    _Callable callable,
    int depth,
    Set<AstNode> visiting,
  ) {
    final String name = parameter.name?.lexeme ?? '';
    if (parameter is FieldFormalParameter) {
      return _member(name, callable.node, depth, visiting);
    }
    final uses = [
      for (final reference in _references[name] ?? const <SimpleIdentifier>[])
        if (_isWithin(reference, callable.node) && _isUnqualified(reference))
          reference,
    ];
    return _traced(name, uses, depth, visiting);
  }

  /// The role of a value returned where [value] is, from the calls of the
  /// enclosing function.
  HardcodedStringVerdict _returned(
    Expression value,
    int depth,
    Set<AstNode> visiting,
  ) {
    final AstNode? function = value
        .thisOrAncestorOfType<FunctionBody>()
        ?.parent;
    final (
      String? name,
      AstNode? declaration,
      bool isGetter,
    ) = switch (function) {
      MethodDeclaration(:final name, :final isGetter) => (
        name.lexeme,
        function,
        isGetter,
      ),
      FunctionExpression(:final parent) when parent is FunctionDeclaration => (
        parent.name.lexeme,
        parent,
        parent.isGetter,
      ),
      _ => (null, null, false),
    };
    if (name == null || visiting.contains(declaration)) {
      return _unknown('returned from a closure');
    }
    final Set<AstNode> inside = {...visiting, declaration!};
    if (isGetter) return _member(name, declaration, depth, inside);
    return _traced(
      '$name()',
      _invocations[name] ?? const <MethodInvocation>[],
      depth,
      inside,
    );
  }

  /// The role of a value stored in the variable [name] declared in
  /// [declarations].
  HardcodedStringVerdict _variable(
    String name,
    AstNode? declarations,
    int depth,
    Set<AstNode> visiting,
  ) {
    final AstNode? owner = declarations?.parent;
    if (owner is FieldDeclaration || owner is TopLevelVariableDeclaration) {
      return _member(name, owner!, depth, visiting);
    }
    final Block? scope = declarations?.thisOrAncestorOfType<Block>();
    final uses = [
      for (final reference in _references[name] ?? const <SimpleIdentifier>[])
        if (scope != null &&
            _isWithin(reference, scope) &&
            reference.offset > declarations!.offset &&
            _isUnqualified(reference))
          reference,
    ];
    return _traced(name, uses, depth, visiting);
  }

  /// The role of a value assigned to [target].
  HardcodedStringVerdict _assigned(
    Expression target,
    int depth,
    Set<AstNode> visiting,
  ) {
    final String? name = switch (target) {
      SimpleIdentifier(:final name) => name,
      PrefixedIdentifier(:final identifier) => identifier.name,
      PropertyAccess(:final propertyName) => propertyName.name,
      _ => null,
    };
    if (name == null) return _unknown('assigned');
    return _member(name, target, depth, visiting);
  }

  /// The role of a value held by the member [name] of the class around
  /// [node], or a top-level one: its uses without a receiver in that class,
  /// and with any receiver in the file, such as `widget.name`.
  HardcodedStringVerdict _member(
    String name,
    AstNode node,
    int depth,
    Set<AstNode> visiting,
  ) {
    final AstNode scope =
        node.thisOrAncestorOfType<ClassDeclaration>() ?? node.root;
    final uses = [
      for (final reference in _references[name] ?? const <SimpleIdentifier>[])
        if (!_isUnqualified(reference) || _isWithin(reference, scope))
          _qualified(reference),
    ];
    return _traced(name, uses, depth, visiting);
  }

  /// The most decisive role of [uses], each one more step deep, behind
  /// [step] in the evidence.
  HardcodedStringVerdict _traced(
    String step,
    List<Expression> uses,
    int depth,
    Set<AstNode> visiting,
  ) {
    final HardcodedStringRole? named = _roleOfName(step);
    if (uses.isEmpty) {
      return named == null
          ? _unknown('$step, not used in this file')
          : _verdict(named, step);
    }
    if (depth >= _maxTraceDepth) return _unknown('$step$_step…');
    final verdicts = [for (final use in uses) _useOf(use, depth + 1, visiting)];
    for (final role in _precedence) {
      for (final verdict in verdicts) {
        if (verdict.role == role &&
            (role != HardcodedStringRole.unknown || named == null)) {
          return _verdict(
            role,
            verdict.evidence.isEmpty ? step : '$step$_step${verdict.evidence}',
          );
        }
      }
    }
    return _verdict(named ?? HardcodedStringRole.unknown, step);
  }

  /// The role the last word of [name] tells, such as presentation for
  /// `searchHint` and data for `userId`; null when it tells none.
  static HardcodedStringRole? _roleOfName(String name) {
    final String word = name.split(_wordStart).last.toLowerCase();
    if (_dataArguments.contains(name) || _dataWords.contains(word)) {
      return HardcodedStringRole.data;
    }
    if (_presentationArguments.contains(name) ||
        _presentationWords.contains(word)) {
      return HardcodedStringRole.presentation;
    }
    return null;
  }

  /// The role of a default value of [parameter].
  HardcodedStringVerdict _defaulted(
    FormalParameter parameter,
    int depth,
    Set<AstNode> visiting,
  ) {
    final AstNode? declaration = parameter
        .thisOrAncestorOfType<FormalParameterList>()
        ?.parent;
    if (declaration == null || visiting.contains(declaration)) {
      return _unknown('default value');
    }
    return _parameter(parameter, _Callable(declaration, null), depth, {
      ...visiting,
      declaration,
    });
  }

  /// Whether [reference] has no receiver, or `this`.
  static bool _isUnqualified(SimpleIdentifier reference) {
    final AstNode? parent = reference.parent;
    return switch (parent) {
      PrefixedIdentifier(:final identifier)
          when identical(identifier, reference) =>
        false,
      PropertyAccess(:final propertyName, :final target)
          when identical(propertyName, reference) =>
        target is ThisExpression,
      _ => true,
    };
  }

  /// [reference] with its receiver, such as `widget.title`.
  static Expression _qualified(SimpleIdentifier reference) {
    final AstNode? parent = reference.parent;
    return switch (parent) {
      PrefixedIdentifier(:final identifier)
          when identical(identifier, reference) =>
        parent,
      PropertyAccess(:final propertyName)
          when identical(propertyName, reference) =>
        parent,
      _ => reference,
    };
  }

  /// Whether [node] lies within [scope].
  static bool _isWithin(AstNode node, AstNode scope) =>
      node.offset >= scope.offset && node.end <= scope.end;

  /// A verdict of [role] decided by [evidence].
  static HardcodedStringVerdict _verdict(
    HardcodedStringRole role,
    String evidence,
  ) => (role: role, evidence: evidence);

  /// An unknown role, after [evidence].
  static HardcodedStringVerdict _unknown(String evidence) =>
      _verdict(HardcodedStringRole.unknown, evidence);
}

/// A method, function or constructor of the file, and its parameters.
class _Callable {
  const _Callable(this.node, this.parameters);

  /// The declaration.
  final AstNode node;

  /// Its parameters; null for a getter.
  final FormalParameterList? parameters;

  /// The parameter an argument named [name], or positional at [index],
  /// binds to; null when none does.
  FormalParameter? parameter(String? name, int index) {
    final List<FormalParameter> all =
        parameters?.parameters ?? const <FormalParameter>[];
    if (name != null) {
      for (final parameter in all) {
        if (parameter.isNamed && parameter.name?.lexeme == name) {
          return parameter;
        }
      }
      return null;
    }
    final positional = all.where((parameter) => parameter.isPositional);
    return index >= 0 && index < positional.length
        ? positional.elementAt(index)
        : null;
  }
}

/// Fills a [HardcodedStringRoleClassifier]'s indexes.
class _DeclarationIndexer extends RecursiveAstVisitor<void> {
  _DeclarationIndexer(this._classifier);

  final HardcodedStringRoleClassifier _classifier;

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final String? className = node
        .thisOrAncestorOfType<ClassDeclaration>()
        ?.namePart
        .typeName
        .lexeme;
    if (className != null) {
      final String? name = node.name?.lexeme;
      _add(
        name == null ? className : '$className.$name',
        node,
        node.parameters,
      );
    }
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _add(node.name.lexeme, node, node.functionExpression.parameters);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _add(node.name.lexeme, node, node.parameters);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    (_classifier._invocations[node.methodName.name] ??= []).add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final AstNode? parent = node.parent;
    final bool isReference =
        !(parent is MethodInvocation && identical(parent.methodName, node)) &&
        !(parent is AssignmentExpression &&
            identical(parent.leftHandSide, node));
    if (isReference) {
      (_classifier._references[node.name] ??= []).add(node);
    }
    super.visitSimpleIdentifier(node);
  }

  /// Indexes the callable [node] under [name].
  void _add(String name, AstNode node, FormalParameterList? parameters) =>
      (_classifier._callables[name] ??= []).add(_Callable(node, parameters));
}
