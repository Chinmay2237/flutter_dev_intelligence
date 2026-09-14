import 'dart:io';
import 'package:yaml/yaml.dart';

import '../../build_doctor/pubspec_analyzer.dart';
import '../../core/models.dart';
import 'ui_rule_base.dart';

/// Checks for asset declaration issues in pubspec.yaml and on the filesystem.
class AssetMissingFileRule extends UiDoctorRule {
  /// Creates a new [AssetMissingFileRule] instance.
  const AssetMissingFileRule();

  @override
  String get id => 'UI_ASSET_MISSING_FILE';

  @override
  String get title => 'Missing Declared Asset File';

  @override
  DiagnosticCategory get category => DiagnosticCategory.pubDependency;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;

  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;

  @override
  String get scope => 'assets';

  @override
  List<DiagnosticFinding> analyzeProject({
    required String projectPath,
    PubspecAnalysisResult? pubspecResult,
  }) {
    final findings = <DiagnosticFinding>[];
    final pubspecFile = File(
      '$projectPath${Platform.pathSeparator}pubspec.yaml',
    );
    if (!pubspecFile.existsSync()) return findings;

    try {
      final doc = loadYaml(pubspecFile.readAsStringSync());
      if (doc is! YamlMap || !doc.containsKey('flutter')) return findings;

      final flutterMap = doc['flutter'];
      if (flutterMap is! YamlMap || !flutterMap.containsKey('assets'))
        return findings;

      final assetsList = flutterMap['assets'];
      if (assetsList is! YamlList) return findings;

      for (final rawAsset in assetsList) {
        final assetPath = rawAsset.toString().trim();
        if (assetPath.isEmpty) continue;

        final normalizedRelPath = assetPath.replaceAll(
          '/',
          Platform.pathSeparator,
        );
        final fullPath =
            '$projectPath${Platform.pathSeparator}$normalizedRelPath';

        final isDirectoryAsset = assetPath.endsWith('/');

        if (isDirectoryAsset) {
          final dir = Directory(fullPath);
          if (!dir.existsSync()) {
            findings.add(
              DiagnosticFinding(
                id: id,
                title: title,
                category: category,
                severity: defaultSeverity,
                confidence: defaultConfidence,
                summary:
                    'Declared asset directory "$assetPath" was not found on disk.',
                likelyCause:
                    'The directory specified under flutter.assets in pubspec.yaml does not exist.',
                source: 'ui_doctor',
                filePath: 'pubspec.yaml',
                primaryStatus: PrimaryStatus.independent,
                evidence: [
                  EvidenceReference(
                    label: 'pubspec.yaml asset entry',
                    value: assetPath,
                    type: 'pubspec',
                  ),
                ],
                recommendations: [
                  FixSuggestion(
                    action:
                        'Create the directory "$assetPath" or remove the entry from pubspec.yaml.',
                  ),
                ],
              ),
            );
          }
        } else {
          final file = File(fullPath);
          if (!file.existsSync()) {
            findings.add(
              DiagnosticFinding(
                id: id,
                title: title,
                category: category,
                severity: defaultSeverity,
                confidence: defaultConfidence,
                summary:
                    'Declared asset file "$assetPath" was not found on disk.',
                likelyCause:
                    'The file specified under flutter.assets in pubspec.yaml does not exist at the designated path.',
                source: 'ui_doctor',
                filePath: 'pubspec.yaml',
                primaryStatus: PrimaryStatus.independent,
                evidence: [
                  EvidenceReference(
                    label: 'pubspec.yaml asset entry',
                    value: assetPath,
                    type: 'pubspec',
                  ),
                ],
                recommendations: [
                  FixSuggestion(
                    action:
                        'Verify the file path or copy "$assetPath" into the project directory.',
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (_) {}

    return findings;
  }
}

/// Detects letter-case mismatches between declared pubspec asset paths and filesystem paths.
class AssetCaseMismatchRule extends UiDoctorRule {
  /// Creates a new [AssetCaseMismatchRule] instance.
  const AssetCaseMismatchRule();

  @override
  String get id => 'UI_ASSET_CASE_MISMATCH';

  @override
  String get title => 'Asset Path Case Sensitivity Mismatch';

  @override
  DiagnosticCategory get category => DiagnosticCategory.generalBuild;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.warning;

  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;

  @override
  String get scope => 'assets';

  @override
  List<DiagnosticFinding> analyzeProject({
    required String projectPath,
    PubspecAnalysisResult? pubspecResult,
  }) {
    final findings = <DiagnosticFinding>[];
    final pubspecFile = File(
      '$projectPath${Platform.pathSeparator}pubspec.yaml',
    );
    if (!pubspecFile.existsSync()) return findings;

    try {
      final doc = loadYaml(pubspecFile.readAsStringSync());
      if (doc is! YamlMap || !doc.containsKey('flutter')) return findings;

      final flutterMap = doc['flutter'];
      if (flutterMap is! YamlMap || !flutterMap.containsKey('assets'))
        return findings;

      final assetsList = flutterMap['assets'];
      if (assetsList is! YamlList) return findings;

      for (final rawAsset in assetsList) {
        final assetPath = rawAsset.toString().trim();
        if (assetPath.isEmpty || assetPath.endsWith('/')) continue;

        final normalizedRelPath = assetPath.replaceAll(
          '/',
          Platform.pathSeparator,
        );
        final file = File(
          '$projectPath${Platform.pathSeparator}$normalizedRelPath',
        );

        final parentDir = file.parent;
        if (parentDir.existsSync()) {
          final basename = file.uri.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
          final entities = parentDir.listSync();
          for (final entity in entities) {
            final actualName = entity.uri.pathSegments.lastWhere(
              (s) => s.isNotEmpty,
              orElse: () => '',
            );
            if (actualName.toLowerCase() == basename.toLowerCase() &&
                actualName != basename) {
              findings.add(
                DiagnosticFinding(
                  id: id,
                  title: title,
                  category: category,
                  severity: defaultSeverity,
                  confidence: defaultConfidence,
                  summary:
                      'Asset filename casing in pubspec.yaml ("$basename") differs from disk ("$actualName").',
                  likelyCause:
                      'File path casing in pubspec.yaml does not match filesystem exact case, which fails on case-sensitive OS environments like Linux CI.',
                  source: 'ui_doctor',
                  filePath: 'pubspec.yaml',
                  primaryStatus: PrimaryStatus.independent,
                  evidence: [
                    EvidenceReference(
                      label: 'Declared path',
                      value: assetPath,
                      type: 'pubspec',
                    ),
                    EvidenceReference(
                      label: 'Disk filename',
                      value: actualName,
                      type: 'filesystem',
                    ),
                  ],
                  recommendations: [
                    FixSuggestion(
                      action:
                          'Update pubspec.yaml asset entry to match exact filesystem case: "$actualName".',
                    ),
                  ],
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    return findings;
  }
}

/// Detects oversized image assets exceeding 2MB file size.
class AssetOversizedRule extends UiDoctorRule {
  /// Creates a new [AssetOversizedRule] instance with optional [maxSizeBytes] threshold.
  const AssetOversizedRule({this.maxSizeBytes = 2097152});

  /// Maximum allowed size in bytes for image asset files.
  final int maxSizeBytes;

  @override
  String get id => 'UI_ASSET_OVERSIZED';

  @override
  String get title => 'Oversized Asset File';

  @override
  DiagnosticCategory get category => DiagnosticCategory.generalBuild;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.warning;

  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;

  @override
  String get scope => 'assets';

  @override
  List<DiagnosticFinding> analyzeProject({
    required String projectPath,
    PubspecAnalysisResult? pubspecResult,
  }) {
    final findings = <DiagnosticFinding>[];
    final pubspecFile = File(
      '$projectPath${Platform.pathSeparator}pubspec.yaml',
    );
    if (!pubspecFile.existsSync()) return findings;

    try {
      final doc = loadYaml(pubspecFile.readAsStringSync());
      if (doc is! YamlMap || !doc.containsKey('flutter')) return findings;

      final flutterMap = doc['flutter'];
      if (flutterMap is! YamlMap || !flutterMap.containsKey('assets'))
        return findings;

      final assetsList = flutterMap['assets'];
      if (assetsList is! YamlList) return findings;

      final checkedFiles = <String>{};

      for (final rawAsset in assetsList) {
        final assetPath = rawAsset.toString().trim();
        if (assetPath.isEmpty) continue;

        final normalizedRelPath = assetPath.replaceAll(
          '/',
          Platform.pathSeparator,
        );
        final fullPath =
            '$projectPath${Platform.pathSeparator}$normalizedRelPath';

        if (assetPath.endsWith('/')) {
          final dir = Directory(fullPath);
          if (dir.existsSync()) {
            for (final entity in dir.listSync(recursive: true)) {
              if (entity is File && !checkedFiles.contains(entity.path)) {
                checkedFiles.add(entity.path);
                _checkFile(entity, projectPath, findings);
              }
            }
          }
        } else {
          final file = File(fullPath);
          if (file.existsSync() && !checkedFiles.contains(file.path)) {
            checkedFiles.add(file.path);
            _checkFile(file, projectPath, findings);
          }
        }
      }
    } catch (_) {}

    return findings;
  }

  void _checkFile(
    File file,
    String projectPath,
    List<DiagnosticFinding> findings,
  ) {
    final size = file.lengthSync();
    if (size > maxSizeBytes) {
      final sizeMb = (size / (1024 * 1024)).toStringAsFixed(2);
      final relPath = file.path.startsWith(projectPath)
          ? file.path
                .substring(projectPath.length)
                .replaceAll(RegExp(r'^[/\\]+'), '')
          : file.path;

      findings.add(
        DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary:
              'Asset "$relPath" is $sizeMb MB, exceeding recommended size threshold (2.0 MB).',
          likelyCause:
              'Uncompressed high-resolution images increase app download bundle size and memory overhead.',
          source: 'ui_doctor',
          filePath: relPath,
          primaryStatus: PrimaryStatus.independent,
          evidence: [
            EvidenceReference(
              label: 'File size',
              value: '$sizeMb MB ($size bytes)',
              type: 'filesystem',
            ),
          ],
          recommendations: [
            FixSuggestion(
              action:
                  'Compress image asset using WebP, PNG resolution scaling, or vector SVG assets.',
            ),
          ],
        ),
      );
    }
  }
}
