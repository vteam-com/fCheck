import 'package:fcheck/src/layers/layers_analyzer.dart';
import 'package:fcheck/src/generators/svg_generator.dart';
import 'dart:io';

void main() {
  // Create a test directory structure
  final testDir = Directory.systemTemp.createTempSync('edge_routing_test');
  print('Created test directory: ${testDir.path}');

  try {
    // Create some test Dart files with dependencies
    final files = [
      {
        'path': 'lib/main.dart',
        'content': '''
import 'package:myapp/services.dart';
import 'package:myapp/utils.dart';

void main() {
  print('Hello World');
}
'''
      },
      {
        'path': 'lib/services.dart',
        'content': '''
import 'package:myapp/repositories.dart';
import 'package:myapp/models.dart';

class AppService {
  final UserRepository userRepo;
  final UserModel currentUser;

  AppService(this.userRepo, this.currentUser);
}
'''
      },
      {
        'path': 'lib/repositories.dart',
        'content': '''
import 'package:myapp/models.dart';

class UserRepository {
  Future<UserModel> getUser(int id) async {
    return UserModel(id: id, name: 'Test User');
  }
}
'''
      },
      {
        'path': 'lib/models.dart',
        'content': '''
class UserModel {
  final int id;
  final String name;

  UserModel({required this.id, required this.name});
}
'''
      },
      {
        'path': 'lib/utils.dart',
        'content': '''
class StringUtils {
  static String capitalize(String input) {
    return input[0].toUpperCase() + input.substring(1);
  }
}
'''
      },
    ];

    // Write test files
    for (final file in files) {
      final filePath = '${testDir.path}/${file['path']!}';
      final dir = Directory(filePath.substring(0, filePath.lastIndexOf('/')));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      File(filePath).writeAsStringSync(file['content']!);
    }

    // Create pubspec.yaml
    File('${testDir.path}/pubspec.yaml').writeAsStringSync('''
name: myapp
environment:
  sdk: '>=2.12.0 <3.0.0'
''');

    // Run layer analysis
    final analyzer = LayersAnalyzer(Directory(testDir.path));
    final result = analyzer.analyzeDirectory(testDir);

    print('Analysis complete:');
    print('- Files analyzed: ${result.dependencyGraph.length}');
    print('- Layers assigned: ${result.layers.length}');
    print('- Issues found: ${result.issues.length}');

    // Generate SVG
    final svgContent = generateDependencyGraphSvg(result);

    // Save SVG to file
    final svgFile = File('${testDir.path}/dependency_graph.svg');
    svgFile.writeAsStringSync(svgContent);
    print('Generated SVG: ${svgFile.path}');

    // Print some stats about the SVG
    final lines = svgContent.split('\n');
    final edgeLines = lines.where((line) => line.contains('<path d="')).length;
    print('SVG stats:');
    print('- Total lines: ${lines.length}');
    print('- Edge paths: $edgeLines');
    print('- File size: ${svgFile.lengthSync()} bytes');

    print('\nTest completed successfully!');
    print('You can open the SVG file to see the improved edge routing:');
    print(svgFile.path);
  } catch (e, stackTrace) {
    print('Error during test: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Clean up (comment out to inspect files)
    // testDir.deleteSync(recursive: true);
  }
}
