class ProjectMetrics {
  final int totalFolders;
  final int totalFiles;
  final int totalDartFiles;
  final int totalLinesOfCode;
  final int totalCommentLines;
  final List<FileMetrics> fileMetrics;

  ProjectMetrics({
    required this.totalFolders,
    required this.totalFiles,
    required this.totalDartFiles,
    required this.totalLinesOfCode,
    required this.totalCommentLines,
    required this.fileMetrics,
  });

  double get commentRatio =>
      totalLinesOfCode == 0 ? 0 : totalCommentLines / totalLinesOfCode;

  void printReport() {
    print('--- Quality Report ---');
    print('Total Folders: $totalFolders');
    print('Total Files: $totalFiles');
    print('Total Dart Files: $totalDartFiles');
    print('Total Lines of Code: $totalLinesOfCode');
    print('Total Comment Lines: $totalCommentLines');
    print('Comment Ratio: ${(commentRatio * 100).toStringAsFixed(2)}%');
    print('----------------------');
    
    final nonCompliant = fileMetrics.where((m) => !m.isOneClassPerFileCompliant).toList();
    if (nonCompliant.isEmpty) {
      print('✅ All files comply with the "one class per file" rule.');
    } else {
      print('❌ ${nonCompliant.length} files violate the "one class per file" rule:');
      for (var m in nonCompliant) {
        print('  - ${m.path} (${m.classCount} classes found)');
      }
    }
  }
}

class FileMetrics {
  final String path;
  final int linesOfCode;
  final int commentLines;
  final int classCount;
  final bool isStatefulWidget;

  FileMetrics({
    required this.path,
    required this.linesOfCode,
    required this.commentLines,
    required this.classCount,
    required this.isStatefulWidget,
  });

  bool get isOneClassPerFileCompliant {
    if (isStatefulWidget) {
      // StatefulWidget usually has 2 classes: the widget and the state.
      return classCount <= 2;
    }
    return classCount <= 1;
  }
}
