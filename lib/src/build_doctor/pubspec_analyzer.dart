import 'dart:io';
import 'package:yaml/yaml.dart';

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
    if (raw.trim().isEmpty) {
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

    try {
      final doc = loadYaml(raw);
      if (doc is! YamlMap) {
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

      final packageName = doc['name']?.toString().trim() ?? '';
      final description = doc['description']?.toString().trim() ?? '';
      final version = doc['version']?.toString().trim() ?? '';

      final depsObj = doc['dependencies'];
      final devDepsObj = doc['dev_dependencies'];
      final envObj = doc['environment'];

      final isFlutterProject =
          doc.containsKey('flutter') ||
          (depsObj is YamlMap && depsObj.containsKey('flutter'));

      final dependencies = <String>[];
      if (depsObj is YamlMap) {
        for (final key in depsObj.keys) {
          final name = key.toString().trim();
          if (name.isNotEmpty) {
            dependencies.add(name);
          }
        }
      }

      final devDependencies = <String>[];
      if (devDepsObj is YamlMap) {
        for (final key in devDepsObj.keys) {
          final name = key.toString().trim();
          if (name.isNotEmpty) {
            devDependencies.add(name);
          }
        }
      }

      final sdkConstraints = <String>[];
      if (envObj is YamlMap) {
        for (final entry in envObj.entries) {
          final k = entry.key.toString().trim();
          final v = entry.value.toString().trim();
          sdkConstraints.add('$k: $v');
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
    } catch (_) {
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
  }
}
