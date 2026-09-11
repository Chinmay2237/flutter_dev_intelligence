import 'dart:io';

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
  };
}

/// Safely inspects a `pubspec.lock` file and summarises dependency sources.
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
        packages: <String>[],
        warnings: <String>['pubspec.lock is missing.'],
        missingExpectedPackages: expectedPackages.toList(growable: false),
        packageVersions: const <String, String>{},
        packageSources: const <String, String>{},
        dependencyKinds: const <String, String>{},
        malformed: false,
      );
    }

    final text = await file.readAsString();
    final lines = text.split(RegExp(r'\r?\n'));

    final packages = <String>[];
    var hosted = 0;
    var git = 0;
    var pathPackages = 0;
    var sdk = 0;
    final warnings = <String>[];
    final packageVersions = <String, String>{};
    final packageSources = <String, String>{};
    final dependencyKinds = <String, String>{};
    var malformed = false;

    String? currentPackage;
    bool inPackagesSection = false;

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      if (trimmed == 'packages:') {
        inPackagesSection = true;
        continue;
      }

      if (!inPackagesSection) {
        continue;
      }

      final packageMatch = RegExp(
        r'^([A-Za-z0-9_.-]+):\s*$',
      ).firstMatch(trimmed);
      if (packageMatch != null) {
        currentPackage = packageMatch.group(1);
        if (currentPackage != null && currentPackage != 'sdks') {
          packages.add(currentPackage);
        }
        continue;
      }

      if (currentPackage == null) {
        continue;
      }

      if (trimmed.startsWith('source:')) {
        final source = trimmed.split(':').skip(1).join(':').trim();
        if (!['hosted', 'git', 'path', 'sdk'].contains(source)) {
          malformed = true;
          warnings.add(
            'Unsupported lockfile source "$source" for $currentPackage.',
          );
        }
        packageSources[currentPackage] = source;
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
            break;
        }
      } else if (trimmed.startsWith('version:')) {
        final version = trimmed.substring('version:'.length).trim();
        packageVersions[currentPackage] = version
            .replaceAll('"', '')
            .replaceAll("'", '');
      } else if (trimmed.startsWith('dependency:')) {
        dependencyKinds[currentPackage] = trimmed
            .substring('dependency:'.length)
            .trim();
      }
    }

    if (packages.isEmpty) {
      warnings.add('No lockfile package entries could be parsed.');
      malformed = true;
    }
    final packagesWithoutSources = packages
        .where((package) => !packageSources.containsKey(package))
        .toList(growable: false);
    if (packagesWithoutSources.isNotEmpty) {
      malformed = true;
      warnings.add(
        'Lockfile package entries without a source: ${packagesWithoutSources.join(', ')}.',
      );
    }
    final missingExpectedPackages = expectedPackages
        .where((package) => !packages.contains(package))
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
    );
  }
}
