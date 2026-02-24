part of 'export_svg_code_size.dart';

/// Counts descendant folder nodes recursively, excluding the synthetic root.
int _countFolders(_FolderTreeNode node) {
  var total = 0;
  for (final child in node.children.values) {
    total += 1;
    total += _countFolders(child);
  }
  return total;
}

/// Returns direct folder/file entries sorted by descending LOC.
List<_FolderEntry> _folderEntriesForNode(_FolderTreeNode node) {
  final entries = <_FolderEntry>[
    for (final child in node.children.values)
      _FolderEntry.folder(
        id: 'folder:${child.path}',
        label: child.name,
        path: child.path,
        size: child.totalSize,
        folder: child,
      ),
    for (final file in node.files)
      _FolderEntry.file(
        id: 'file:${file.stableId}',
        label: p.basename(file.filePath),
        path: file.filePath,
        size: file.linesOfCode,
      ),
  ];
  entries.sort((left, right) => right.size.compareTo(left.size));
  return entries;
}

/// Builds class groups and maps global functions to a synthetic class `<...>`.
Map<String, List<_ClassGroup>> _buildClassGroupsByFile(
  List<CodeSizeArtifact> classItems,
  List<CodeSizeArtifact> callableItems, {
  required Map<String, int> fileLocByPath,
}) {
  final classItemsByFile = <String, List<CodeSizeArtifact>>{};
  for (final classArtifact in classItems) {
    classItemsByFile
        .putIfAbsent(classArtifact.filePath, () => <CodeSizeArtifact>[])
        .add(classArtifact);
  }

  final methodsByFileOwner = <String, Map<String, List<CodeSizeArtifact>>>{};
  final globalsByFile = <String, List<CodeSizeArtifact>>{};
  for (final callable in callableItems) {
    final filePath = callable.filePath;
    if (callable.kind == CodeSizeArtifactKind.function &&
        (callable.ownerName == null || callable.ownerName!.isEmpty)) {
      globalsByFile
          .putIfAbsent(filePath, () => <CodeSizeArtifact>[])
          .add(callable);
      continue;
    }
    final owner = callable.ownerName;
    if (owner == null || owner.isEmpty) {
      globalsByFile
          .putIfAbsent(filePath, () => <CodeSizeArtifact>[])
          .add(callable);
      continue;
    }
    methodsByFileOwner
        .putIfAbsent(filePath, () => <String, List<CodeSizeArtifact>>{})
        .putIfAbsent(owner, () => <CodeSizeArtifact>[])
        .add(callable);
  }

  final filePaths = <String>{
    ...classItemsByFile.keys,
    ...methodsByFileOwner.keys,
    ...globalsByFile.keys,
  };
  final groupsByFile = <String, List<_ClassGroup>>{};
  for (final filePath in filePaths) {
    final fileClasses =
        classItemsByFile[filePath] ?? const <CodeSizeArtifact>[];
    final methodsByOwner =
        methodsByFileOwner[filePath] ??
        const <String, List<CodeSizeArtifact>>{};
    final globals = globalsByFile[filePath] ?? const <CodeSizeArtifact>[];

    final groups = <_ClassGroup>[];
    final declaredClassNames = <String>{};
    for (final classArtifact in fileClasses) {
      final className = classArtifact.name;
      declaredClassNames.add(className);
      final methods = methodsByOwner[className] ?? const <CodeSizeArtifact>[];
      final methodsSize = methods.fold<int>(
        0,
        (sum, method) => sum + method.linesOfCode,
      );
      final size = math.max(classArtifact.linesOfCode, methodsSize);
      groups.add(
        _ClassGroup(
          label: className,
          sourcePath: filePath,
          size: size,
          callables: methods,
        ),
      );
    }

    for (final entry in methodsByOwner.entries) {
      if (declaredClassNames.contains(entry.key)) {
        continue;
      }
      final methodsSize = entry.value.fold<int>(
        0,
        (sum, method) => sum + method.linesOfCode,
      );
      groups.add(
        _ClassGroup(
          label: entry.key,
          sourcePath: filePath,
          size: methodsSize,
          callables: entry.value,
        ),
      );
    }

    if (globals.isNotEmpty) {
      final globalSize = globals.fold<int>(
        0,
        (sum, function) => sum + function.linesOfCode,
      );
      groups.add(
        _ClassGroup(
          label: _globalFunctionsClassLabel,
          sourcePath: filePath,
          size: globalSize,
          callables: globals,
        ),
      );
    }

    groups.sort((left, right) => right.size.compareTo(left.size));
    if (groups.isNotEmpty) {
      groupsByFile[filePath] = groups;
    }
  }
  return _applyFileRollupBudget(groupsByFile, fileLocByPath);
}

/// Removes callables nested inside other callables to avoid double counting.
List<CodeSizeArtifact> _filterNestedCallables(
  List<CodeSizeArtifact> callables,
) {
  final byFile = <String, List<CodeSizeArtifact>>{};
  for (final callable in callables) {
    byFile
        .putIfAbsent(callable.filePath, () => <CodeSizeArtifact>[])
        .add(callable);
  }

  final filtered = <CodeSizeArtifact>[];
  for (final fileCallables in byFile.values) {
    for (final candidate in fileCallables) {
      final isNested = fileCallables.any((other) {
        if (identical(other, candidate)) {
          return false;
        }
        if (other.startLine == candidate.startLine &&
            other.endLine == candidate.endLine) {
          return other.name.length > candidate.name.length;
        }
        return other.startLine <= candidate.startLine &&
            other.endLine >= candidate.endLine &&
            (other.startLine < candidate.startLine ||
                other.endLine > candidate.endLine);
      });
      if (!isNested) {
        filtered.add(candidate);
      }
    }
  }
  return filtered;
}

/// Applies per-file LOC budgets so class/callable rollups do not exceed file LOC.
Map<String, List<_ClassGroup>> _applyFileRollupBudget(
  Map<String, List<_ClassGroup>> groupsByFile,
  Map<String, int> fileLocByPath,
) {
  final output = <String, List<_ClassGroup>>{};
  for (final entry in groupsByFile.entries) {
    final filePath = entry.key;
    var remaining = fileLocByPath[filePath] ?? 0;
    final nextGroups = <_ClassGroup>[];
    for (final group in entry.value) {
      if (remaining <= 0) {
        break;
      }
      final groupSize = math.min(group.size, remaining);
      remaining -= groupSize;
      var callableBudget = groupSize;
      final callables = <CodeSizeArtifact>[];
      for (final callable in group.callables) {
        if (callableBudget <= 0) {
          break;
        }
        final callableSize = math.min(callable.linesOfCode, callableBudget);
        callableBudget -= callableSize;
        if (callableSize <= 0) {
          continue;
        }
        callables.add(
          CodeSizeArtifact(
            kind: callable.kind,
            name: callable.name,
            filePath: callable.filePath,
            linesOfCode: callableSize,
            startLine: callable.startLine,
            endLine: callable.endLine,
            ownerName: callable.ownerName,
          ),
        );
      }
      if (groupSize <= 0) {
        continue;
      }
      nextGroups.add(
        _ClassGroup(
          label: group.label,
          sourcePath: group.sourcePath,
          size: groupSize,
          callables: callables,
        ),
      );
    }
    if (nextGroups.isNotEmpty) {
      output[filePath] = nextGroups;
    }
  }
  return output;
}

/// Builds rolled-up file artifacts from grouped class/function totals.
List<CodeSizeArtifact> _buildRolledUpFileItems(
  List<CodeSizeArtifact> fileItems,
  Map<String, List<_ClassGroup>> classGroupsByFile,
) {
  return fileItems
      .map((file) {
        final groups =
            classGroupsByFile[file.filePath] ?? const <_ClassGroup>[];
        final rolled = groups.fold<int>(0, (sum, group) => sum + group.size);
        if (rolled <= 0) {
          return file;
        }
        return CodeSizeArtifact(
          kind: file.kind,
          name: file.name,
          filePath: file.filePath,
          linesOfCode: rolled,
          startLine: file.startLine,
          endLine: file.endLine,
          ownerName: file.ownerName,
        );
      })
      .toList(growable: false);
}

/// Builds a folder tree from file artifacts.
///
/// Files are stored at their direct folder node and folder totals are derived
/// recursively from children + local files.
_FolderTreeNode _buildFolderTree(List<CodeSizeArtifact> fileItems) {
  final root = _FolderTreeNode(name: '.', path: '.');
  for (final file in fileItems) {
    final directory = p.normalize(p.dirname(file.filePath));
    final segments = directory == '.' || directory.isEmpty
        ? const <String>[]
        : p.split(directory).where((segment) => segment.isNotEmpty).toList();
    var current = root;
    for (final segment in segments) {
      final childPath = current.path == '.'
          ? segment
          : p.join(current.path, segment);
      current = current.children.putIfAbsent(
        segment,
        () => _FolderTreeNode(name: segment, path: childPath),
      );
    }
    current.files.add(file);
  }
  return root;
}

/// Converts absolute artifact paths to project-relative paths when [base]
/// is provided.
///
/// Relative input paths are preserved unchanged.
CodeSizeArtifact _rebaseArtifactPath(CodeSizeArtifact artifact, String? base) {
  if (base == null) {
    return artifact;
  }
  final filePath = artifact.filePath;
  final normalizedPath = p.normalize(filePath);
  if (!p.isAbsolute(normalizedPath)) {
    return artifact;
  }

  final relativePath = p.relative(normalizedPath, from: base);
  return CodeSizeArtifact(
    kind: artifact.kind,
    name: artifact.name,
    filePath: relativePath,
    linesOfCode: artifact.linesOfCode,
    startLine: artifact.startLine,
    endLine: artifact.endLine,
    ownerName: artifact.ownerName,
  );
}
