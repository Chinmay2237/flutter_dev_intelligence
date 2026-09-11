import 'dart:io';

/// Structured result of inspecting a project directory.
class ProjectInspectionResult {
  const ProjectInspectionResult({
    required this.path,
    required this.exists,
    required this.hasPubspec,
    required this.isFlutterProject,
    required this.platformFolders,
    required this.libFolderExists,
    required this.testFolderExists,
  });

  final String path;
  final bool exists;
  final bool hasPubspec;
  final bool isFlutterProject;
  final List<String> platformFolders;
  final bool libFolderExists;
  final bool testFolderExists;

  Map<String, dynamic> toJson() => {
    'path': path,
    'exists': exists,
    'hasPubspec': hasPubspec,
    'isFlutterProject': isFlutterProject,
    'platformFolders': platformFolders,
    'libFolderExists': libFolderExists,
    'testFolderExists': testFolderExists,
  };
}

/// Scans a project directory and reports whether it looks like a Flutter project.
class FlutterProjectScanner {
  const FlutterProjectScanner();

  static Future<ProjectInspectionResult> scan(String projectPath) async {
    final resolved = projectPath.trim();
    final directory = Directory(resolved);
    final exists = await directory.exists();

    if (!exists) {
      return ProjectInspectionResult(
        path: resolved,
        exists: false,
        hasPubspec: false,
        isFlutterProject: false,
        platformFolders: const <String>[],
        libFolderExists: false,
        testFolderExists: false,
      );
    }

    final pubspecFile = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    final hasPubspec = await pubspecFile.exists();
    final libFolderExists = await Directory(
      '${directory.path}${Platform.pathSeparator}lib',
    ).exists();
    final testFolderExists = await Directory(
      '${directory.path}${Platform.pathSeparator}test',
    ).exists();

    final platformNames = <String>[];
    for (final folderName in const [
      'android',
      'ios',
      'web',
      'windows',
      'macos',
      'linux',
    ]) {
      final folder = Directory(
        '${directory.path}${Platform.pathSeparator}$folderName',
      );
      if (await folder.exists()) {
        platformNames.add(folderName);
      }
    }

    var isFlutterProject = hasPubspec;
    if (hasPubspec) {
      final content = await pubspecFile.readAsString();
      isFlutterProject =
          content.contains('flutter:') || content.contains('sdk: flutter');
    }

    return ProjectInspectionResult(
      path: directory.path,
      exists: true,
      hasPubspec: hasPubspec,
      isFlutterProject: isFlutterProject,
      platformFolders: platformNames,
      libFolderExists: libFolderExists,
      testFolderExists: testFolderExists,
    );
  }
}
