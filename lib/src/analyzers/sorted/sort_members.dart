import 'package:analyzer/dart/ast/ast.dart';

/// Sorts members inside a class body so that:
/// 1) non-method members (fields, constructors, etc.) remain first in their original order
/// 2) all public methods (alphabetical) come next
/// 3) all private methods (alphabetical) come last
class MemberSorter {
  /// Creates a new MemberSorter.
  ///
  /// [_content] The full source code of the file containing the class.
  /// [_members] The list of class members to sort.
  MemberSorter(this._content, this._members);

  final String _content;
  final NodeList<ClassMember> _members;

  /// Returns the sorted class body as a string.
  ///
  /// This method reorganizes the class members according to Flutter conventions:
  /// - Constructors, fields, and other non-method members first (original order)
  /// - Lifecycle methods (initState, dispose, build, etc.) in specific order
  /// - Public methods alphabetically
  /// - Private methods alphabetically
  ///
  /// Returns the sorted class body content as a string, or empty string if no members.
  String getSortedBody() {
    final NodeList<ClassMember> members = _members;
    if (members.isEmpty) {
      return '';
    }

    final List<String> otherMembers = <String>[];
    final List<_SortableMethod> lifecycleMethods = <_SortableMethod>[];
    final List<_SortableMethod> publicMethods = <_SortableMethod>[];
    final List<_SortableMethod> privateMethods = <_SortableMethod>[];

    final Set<String> lifecycleMethodNames = <String>{
      'initState',
      'dispose',
      'didChangeDependencies',
      'didUpdateWidget',
      'build',
    };

    // Map from field name to list of member sources (field + associated getters/setters)
    final Map<String, List<String>> fieldGroups = <String, List<String>>{};
    // Keep track of which members have been grouped (to skip later)
    final Set<ClassMember> groupedMembers = <ClassMember>{};

    // First, group FieldDeclarations and their associated PropertyAccessorDeclarations
    for (final ClassMember member in members) {
      if (member is FieldDeclaration) {
        // For each variable declared in the field
        for (final VariableDeclaration variable in member.fields.variables) {
          final String name = variable.name.lexeme;
          final List<String> groupSources = <String>[];
          groupSources.add(_getSource(member));
          fieldGroups[name] = groupSources;
          groupedMembers.add(member);
        }
      }
    }

    // Now associate PropertyAccessorDeclarations (getters/setters) with their fields if possible
    for (final ClassMember member in members) {
      if (member is MethodDeclaration && (member.isGetter || member.isSetter)) {
        final String name = member.name.lexeme;
        if (fieldGroups.containsKey(name)) {
          fieldGroups[name]!.add(_getSource(member));
          groupedMembers.add(member);
        }
      }
    }

    // Add non-field, non-method members (e.g., constructors) in original order at the top
    for (final ClassMember member in members) {
      if (!groupedMembers.contains(member) && member is! MethodDeclaration) {
        otherMembers.add(_getSource(member));
      }
    }

    // Collect fields and their grouped accessors into a list and sort alphabetically
    final List<_SortableField> sortedFields = <_SortableField>[];
    for (final String fieldName in fieldGroups.keys) {
      sortedFields.add(_SortableField(fieldName, fieldGroups[fieldName]!));
    }
    sortedFields.sort(
      (final _SortableField a, final _SortableField b) =>
          a.name.compareTo(b.name),
    );

    // Add sorted fields to otherMembers
    for (final _SortableField field in sortedFields) {
      otherMembers.addAll(field.sources);
    }

    // Now process standalone methods only (exclude getters/setters which were grouped)
    for (final ClassMember member in members) {
      if (member is MethodDeclaration && !groupedMembers.contains(member)) {
        final String name = member.name.lexeme;
        if (lifecycleMethodNames.contains(name)) {
          lifecycleMethods.add(_SortableMethod(name, _getSource(member)));
        } else if (name.startsWith('_')) {
          privateMethods.add(_SortableMethod(name, _getSource(member)));
        } else {
          publicMethods.add(_SortableMethod(name, _getSource(member)));
        }
      }
    }

    // Sort lifecycle methods in fixed order (preserve exact order as in lifecycleOrder)
    final List<String> lifecycleOrder = <String>[
      'initState',
      'dispose',
      'didChangeDependencies',
      'didUpdateWidget',
      'build',
    ];

    final Map<String, int> lifecycleOrderMap = <String, int>{
      for (int i = 0; i < lifecycleOrder.length; i++) lifecycleOrder[i]: i,
    };

    /// Default sort order for unknown lifecycle methods.
    const int defaultLifecycleSortOrder = 999;

    lifecycleMethods.sort(
      (final _SortableMethod a, final _SortableMethod b) =>
          (lifecycleOrderMap[a.name] ?? defaultLifecycleSortOrder).compareTo(
            lifecycleOrderMap[b.name] ?? defaultLifecycleSortOrder,
          ),
    );
    publicMethods.sort(
      (final _SortableMethod a, final _SortableMethod b) =>
          a.name.compareTo(b.name),
    );

    privateMethods.sort(
      (final _SortableMethod a, final _SortableMethod b) =>
          a.name.compareTo(b.name),
    );

    final List<String> parts = <String>[];
    if (otherMembers.isNotEmpty) {
      parts.addAll(otherMembers.map((final String s) => s.trimRight()));
    }
    if (lifecycleMethods.isNotEmpty) {
      parts.addAll(
        lifecycleMethods.map((final _SortableMethod m) => m.source.trimRight()),
      );
    }
    if (publicMethods.isNotEmpty) {
      parts.addAll(
        publicMethods.map((final _SortableMethod m) => m.source.trimRight()),
      );
    }
    if (privateMethods.isNotEmpty) {
      parts.addAll(
        privateMethods.map((final _SortableMethod m) => m.source.trimRight()),
      );
    }

    final String result = parts.join('\n');
    return result.isEmpty ? '' : '\n$result\n';
  }

  String _getSource(final AstNode node) =>
      _content.substring(node.offset, node.end);
}

class _SortableMethod {
  _SortableMethod(this.name, this.source);
  final String name;
  final String source;
}

class _SortableField {
  _SortableField(this.name, this.sources);
  final String name;
  final List<String> sources;
}
