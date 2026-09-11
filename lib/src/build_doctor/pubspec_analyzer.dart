import 'dart:io';

/// Structured summary of a project's `pubspec.yaml`.
class PubspecAnalysisResult {
  const PubspecAnalysisResult({
    required this.packageName,
    required this.description,
    required this.version,
    required this.isFlutterProject,
    required this.dependencies,
    required this.devDependencies,
    required this.sdkConstraints,
  });

  final String packageName;
  final String description;
  final String version;
  final bool isFlutterProject;
  final List<String> dependencies;
  final List<String> devDependencies;
  final List<String> sdkConstraints;

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'description': description,
    'version': version,
    'isFlutterProject': isFlutterProject,
    'dependencies': dependencies,
    'devDependencies': devDependencies,
    'sdkConstraints': sdkConstraints,
  };
}

/// Reads and summarizes a Flutter/Dart project's `pubspec.yaml`.
class PubspecAnalyzer {
  const PubspecAnalyzer();

  static Future<PubspecAnalysisResult> analyze(String projectPath) async {
    final dir = Directory(projectPath);
    final path = '${dir.path}${Platform.pathSeparator}pubspec.yaml';
    final file = File(path);

    if (!await file.exists()) {
      return const PubspecAnalysisResult(
        packageName: '',
        description: '',
        version: '',
        isFlutterProject: false,
        dependencies: <String>[],
        devDependencies: <String>[],
        sdkConstraints: <String>[],
      );
    }

    final raw = await file.readAsString();
    final lines = raw.split(RegExp(r'\r?\n'));

    var packageName = '';
    var description = '';
    var version = '';
    var isFlutterProject = false;
    final dependencies = <String>[];
    final devDependencies = <String>[];
    final sdkConstraints = <String>[];

    var inDependencies = false;
    var inDevDependencies = false;
    var inEnvironment = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final isTopLevel = line.trimLeft().length == line.length;
      if (isTopLevel && trimmed.endsWith(':')) {
        if (trimmed == 'dependencies:') {
          inDependencies = true;
          inDevDependencies = false;
          inEnvironment = false;
        } else if (trimmed == 'dev_dependencies:') {
          inDevDependencies = true;
          inDependencies = false;
          inEnvironment = false;
        } else if (trimmed == 'environment:') {
          inEnvironment = true;
          inDependencies = false;
          inDevDependencies = false;
        } else if (trimmed == 'flutter:') {
          isFlutterProject = true;
          inDependencies = false;
          inDevDependencies = false;
          inEnvironment = false;
        } else {
          inDependencies = false;
          inDevDependencies = false;
          inEnvironment = false;
        }
        continue;
      }

      if (trimmed.startsWith('name:')) {
        packageName = trimmed.substring('name:'.length).trim();
        continue;
      }

      if (trimmed.startsWith('description:')) {
        description = trimmed.substring('description:'.length).trim();
        continue;
      }

      if (trimmed.startsWith('version:')) {
        version = trimmed.substring('version:'.length).trim();
        continue;
      }

      if (trimmed.startsWith('environment:')) {
        inEnvironment = true;
        continue;
      }

      if (trimmed.startsWith('dependencies:')) {
        inDependencies = true;
        inDevDependencies = false;
        inEnvironment = false;
        continue;
      }

      if (trimmed.startsWith('dev_dependencies:')) {
        inDevDependencies = true;
        inDependencies = false;
        inEnvironment = false;
        continue;
      }

      if (trimmed.startsWith('flutter:')) {
        isFlutterProject = true;
        if (inDependencies || inDevDependencies) {
          continue;
        }
        inDependencies = false;
        inDevDependencies = false;
        inEnvironment = false;
        continue;
      }

      if (inEnvironment && trimmed.contains(':')) {
        sdkConstraints.add(trimmed.replaceAll(':', ': '));
        continue;
      }

      if (inDependencies &&
          !trimmed.startsWith('sdk:') &&
          !trimmed.startsWith('flutter:') &&
          trimmed.contains(':')) {
        final key = trimmed.split(':').first.trim();
        if (key.isNotEmpty) {
          dependencies.add(key);
        }
      }

      if (inDevDependencies && trimmed.contains(':')) {
        final key = trimmed.split(':').first.trim();
        if (key.isNotEmpty) {
          devDependencies.add(key);
        }
      }
    }

    return PubspecAnalysisResult(
      packageName: packageName,
      description: description,
      version: version,
      isFlutterProject: isFlutterProject,
      dependencies: dependencies,
      devDependencies: devDependencies,
      sdkConstraints: sdkConstraints,
    );
  }
}
