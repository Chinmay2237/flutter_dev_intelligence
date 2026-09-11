import 'dart:io';
import 'package:yaml/yaml.dart';

/// Result of analyzing a `pubspec.lock` file.
class PubspecLockAnalysisResult {
  const PubspecLockAnalysisResult({
    required this.exists,
    required this.packageCount,
    required this.hostedPackageCount,
    required this.gitPackageCount,
    required this.pathPackageCount,
    required this.sdkPackageCount,
    required this.packages,
    required this.warnings,
    required this.missingExpectedPackages,
    required this.packageVersions,
    required this.packageSources,
    required this.dependencyKinds,
    required this.malformed,
    this.directMainCount = 0,
    this.directDevCount = 0,
    this.transitiveCount = 0,
  });

  final bool exists;
  final int packageCount;
  final int hostedPackageCount;
  final int gitPackageCount;
  final int pathPackageCount;
  final int sdkPackageCount;
  final List<String> packages;
  final List<String> warnings;
  final List<String> missingExpectedPackages;
  final Map<String, String> packageVersions;
  final Map<String, String> packageSources;
  final Map<String, String> dependencyKinds;
  final bool malformed;
  final int directMainCount;
  final int directDevCount;
  final int transitiveCount;

  Map<String, dynamic> toJson() => {
    'exists': exists,
    'packageCount': packageCount,
    'hostedPackageCount': hostedPackageCount,
    'gitPackageCount': gitPackageCount,
    'pathPackageCount': pathPackageCount,
    'sdkPackageCount': sdkPackageCount,
    'packages': packages,
    'warnings': warnings,
    'missingExpectedPackages': missingExpectedPackages,
    'packageVersions': packageVersions,
    'packageSources': packageSources,
    'dependencyKinds': dependencyKinds,
    'malformed': malformed,
    'directMainCount': directMainCount,
    'directDevCount': directDevCount,
    'transitiveCount': transitiveCount,
  };
}

/// Safely inspects a `pubspec.lock` file using YAML parsing and summarizes dependency sources.
class PubspecLockAnalyzer {
  const PubspecLockAnalyzer();

  static Future<PubspecLockAnalysisResult> analyze(
    String projectPath, {
    Iterable<String> expectedPackages = const <String>[],
  }) async {
    final lockFilePath =
        '${projectPath.replaceAll(RegExp(r'/$'), '')}${Platform.pathSeparator}pubspec.lock';
    final file = File(lockFilePath);
    final exists = await file.exists();

    if (!exists) {
      return PubspecLockAnalysisResult(
        exists: false,
        packageCount: 0,
        hostedPackageCount: 0,
        gitPackageCount: 0,
        pathPackageCount: 0,
        sdkPackageCount: 0,
        packages: const <String>[],
        warnings: const <String>['pubspec.lock is missing.'],
        missingExpectedPackages: expectedPackages.toList(growable: false),
        packageVersions: const <String, String>{},
        packageSources: const <String, String>{},
        dependencyKinds: const <String, String>{},
        malformed: false,
      );
    }

    final text = await file.readAsString();
    if (text.trim().isEmpty) {
      return PubspecLockAnalysisResult(
        exists: true,
        packageCount: 0,
        hostedPackageCount: 0,
        gitPackageCount: 0,
        pathPackageCount: 0,
        sdkPackageCount: 0,
        packages: const <String>[],
        warnings: const <String>['pubspec.lock is empty.'],
        missingExpectedPackages: expectedPackages.toList(growable: false),
        packageVersions: const <String, String>{},
        packageSources: const <String, String>{},
        dependencyKinds: const <String, String>{},
        malformed: true,
      );
    }

    YamlMap yamlMap;
    try {
      final doc = loadYaml(text);
      if (doc is! YamlMap) {
        return PubspecLockAnalysisResult(
          exists: true,
          packageCount: 0,
          hostedPackageCount: 0,
          gitPackageCount: 0,
          pathPackageCount: 0,
          sdkPackageCount: 0,
          packages: const <String>[],
          warnings: const <String>['pubspec.lock is not a valid YAML map.'],
          missingExpectedPackages: expectedPackages.toList(growable: false),
          packageVersions: const <String, String>{},
          packageSources: const <String, String>{},
          dependencyKinds: const <String, String>{},
          malformed: true,
        );
      }
      yamlMap = doc;
    } catch (e) {
      return PubspecLockAnalysisResult(
        exists: true,
        packageCount: 0,
        hostedPackageCount: 0,
        gitPackageCount: 0,
        pathPackageCount: 0,
        sdkPackageCount: 0,
        packages: const <String>[],
        warnings: <String>['Failed to parse pubspec.lock YAML: $e'],
        missingExpectedPackages: expectedPackages.toList(growable: false),
        packageVersions: const <String, String>{},
        packageSources: const <String, String>{},
        dependencyKinds: const <String, String>{},
        malformed: true,
      );
    }

    final packagesObj = yamlMap['packages'];
    if (packagesObj is! YamlMap) {
      return PubspecLockAnalysisResult(
        exists: true,
        packageCount: 0,
        hostedPackageCount: 0,
        gitPackageCount: 0,
        pathPackageCount: 0,
        sdkPackageCount: 0,
        packages: const <String>[],
        warnings: const <String>[
          'No lockfile package entries could be parsed.',
        ],
        missingExpectedPackages: expectedPackages.toList(growable: false),
        packageVersions: const <String, String>{},
        packageSources: const <String, String>{},
        dependencyKinds: const <String, String>{},
        malformed: true,
      );
    }

    final packages = <String>[];
    var hosted = 0;
    var git = 0;
    var pathPackages = 0;
    var sdk = 0;
    var directMain = 0;
    var directDev = 0;
    var transitive = 0;
    final warnings = <String>[];
    final packageVersions = <String, String>{};
    final packageSources = <String, String>{};
    final dependencyKinds = <String, String>{};
    var malformed = false;

    for (final entry in packagesObj.entries) {
      final packageName = entry.key.toString();
      if (packageName == 'sdks') continue;

      packages.add(packageName);
      final details = entry.value;
      if (details is! YamlMap) {
        malformed = true;
        warnings.add('Package entry $packageName is not a map.');
        continue;
      }

      final source = details['source']?.toString();
      final version = details['version']?.toString();
      final dependency = details['dependency']?.toString();

      if (source != null) {
        packageSources[packageName] = source;
        switch (source) {
          case 'sdk':
            sdk += 1;
            break;
          case 'git':
            git += 1;
            break;
          case 'path':
            pathPackages += 1;
            break;
          case 'hosted':
            hosted += 1;
            break;
          default:
            malformed = true;
            warnings.add(
              'Unsupported lockfile source "$source" for $packageName.',
            );
            break;
        }
      } else {
        malformed = true;
        warnings.add('Lockfile package entry $packageName has no source.');
      }

      if (version != null) {
        packageVersions[packageName] = version
            .replaceAll('"', '')
            .replaceAll("'", '');
      }

      if (dependency != null) {
        final cleanDependency = dependency
            .replaceAll('"', '')
            .replaceAll("'", '')
            .trim();
        dependencyKinds[packageName] = cleanDependency;
        if (cleanDependency.contains('direct main')) {
          directMain += 1;
        } else if (cleanDependency.contains('direct dev')) {
          directDev += 1;
        } else if (cleanDependency.contains('transitive')) {
          transitive += 1;
        }
      }
    }

    if (packages.isEmpty) {
      warnings.add('No lockfile package entries could be parsed.');
      malformed = true;
    }

    final missingExpectedPackages = expectedPackages
        .where(
          (package) =>
              package != 'sdk' &&
              package != 'flutter' &&
              package != 'sky_engine' &&
              !packages.contains(package),
        )
        .toList(growable: false);
    if (missingExpectedPackages.isNotEmpty) {
      warnings.add(
        'Dependencies declared in pubspec.yaml but absent from pubspec.lock: '
        '${missingExpectedPackages.join(', ')}.',
      );
    }

    return PubspecLockAnalysisResult(
      exists: true,
      packageCount: packages.length,
      hostedPackageCount: hosted,
      gitPackageCount: git,
      pathPackageCount: pathPackages,
      sdkPackageCount: sdk,
      packages: packages,
      warnings: warnings,
      missingExpectedPackages: missingExpectedPackages,
      packageVersions: packageVersions,
      packageSources: packageSources,
      dependencyKinds: dependencyKinds,
      malformed: malformed,
      directMainCount: directMain,
      directDevCount: directDev,
      transitiveCount: transitive,
    );
  }
}
