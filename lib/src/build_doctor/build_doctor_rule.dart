import '../core/models.dart';

/// Base class for deterministic build log diagnostic rules.
abstract class BuildDoctorRule {
  const BuildDoctorRule();

  String get id;
  String get title;
  DiagnosticCategory get category => DiagnosticCategory.build;
  DiagnosticSeverity get severity => DiagnosticSeverity.high;
  String get description;
  List<String> get suggestions;
  double get confidence => 0.8;

  /// Returns true if this rule matches the normalized build log.
  bool matches(String cleanLog);

  /// Extract snippet evidence from the build log.
  String extractEvidence(String cleanLog) {
    final lowerLog = cleanLog.toLowerCase();
    final key = id.replaceAll('_', ' ');
    final index = lowerLog.indexOf(key);
    if (index != -1) {
      final start = (index - 40).clamp(0, cleanLog.length);
      final end = (index + 180).clamp(0, cleanLog.length);
      return cleanLog.substring(start, end).trim();
    }
    return cleanLog.substring(0, cleanLog.length > 220 ? 220 : cleanLog.length);
  }

  /// Builds a DiagnosticIssue for this rule.
  DiagnosticIssue createIssue(String cleanLog) {
    return DiagnosticIssue(
      id: id,
      category: category,
      severity: severity,
      title: title,
      description: description,
      source: 'build log',
      evidence: [
        EvidenceReference(
          type: EvidenceType.log,
          label: 'build-log',
          value: extractEvidence(cleanLog),
        ),
      ],
      suggestions: suggestions
          .map(
            (s) => FixSuggestion(
              action: s,
              details: s,
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          )
          .toList(),
      confidence: confidence,
    );
  }
}

// ==========================================
// DART & FLUTTER BUILD RULES
// ==========================================

class KotlinGradleMismatchRule extends BuildDoctorRule {
  const KotlinGradleMismatchRule();
  @override
  String get id => 'kotlin_gradle_mismatch';
  @override
  String get title => 'Potential Kotlin/Gradle compatibility issue';
  @override
  String get description =>
      'The build log suggests a Kotlin and Android Gradle Plugin compatibility mismatch.';
  @override
  List<String> get suggestions => const [
    'Verify the Kotlin and Android Gradle Plugin versions are compatible.',
  ];
  @override
  double get confidence => 0.82;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('kotlin') && l.contains('gradle') && l.contains('plugin');
  }
}

class DuplicateClassRule extends BuildDoctorRule {
  const DuplicateClassRule();
  @override
  String get id => 'duplicate_class';
  @override
  String get title => 'Duplicate class detected';
  @override
  String get description =>
      'The build log indicates that the same class appears in multiple dependency modules.';
  @override
  List<String> get suggestions => const [
    'Check dependencies and duplicate module/class entries in the Android build configuration.',
  ];
  @override
  double get confidence => 0.87;
  @override
  bool matches(String cleanLog) =>
      cleanLog.toLowerCase().contains('duplicate class');
}

class CompileErrorRule extends BuildDoctorRule {
  const CompileErrorRule();
  @override
  String get id => 'compile_error';
  @override
  String get title => 'Source compilation error detected';
  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;
  @override
  String get description =>
      'The log indicates a Dart or Java/Kotlin compile error that may block the build.';
  @override
  List<String> get suggestions => const [
    'Review the exact compile error and verify imports, symbols, and generated code.',
  ];
  @override
  double get confidence => 0.72;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('cannot find symbol') ||
        l.contains('undefined identifier') ||
        l.contains('compilation failed');
  }
}

class AndroidSdkMissingRule extends BuildDoctorRule {
  const AndroidSdkMissingRule();
  @override
  String get id => 'android_sdk_missing';
  @override
  String get title => 'Android SDK component may be missing';
  @override
  String get description =>
      'The build output indicates that an Android SDK component could not be found.';
  @override
  List<String> get suggestions => const [
    'Install the required Android SDK component and verify ANDROID_HOME.',
  ];
  @override
  double get confidence => 0.86;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('android sdk') &&
        (l.contains('not found') || l.contains('missing'));
  }
}

class JavaRuntimeMismatchRule extends BuildDoctorRule {
  const JavaRuntimeMismatchRule();
  @override
  String get id => 'java_runtime_mismatch';
  @override
  DiagnosticCategory get category => DiagnosticCategory.java;
  @override
  String get title => 'Java runtime compatibility issue';
  @override
  String get description =>
      'The build output indicates an incompatible or unavailable Java runtime.';
  @override
  List<String> get suggestions => const [
    'Verify the configured JDK version and JAVA_HOME for the Flutter toolchain.',
  ];
  @override
  double get confidence => 0.8;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('java home') ||
        l.contains('unsupported class file major version');
  }
}

class DependencyResolutionFailedRule extends BuildDoctorRule {
  const DependencyResolutionFailedRule();
  @override
  String get id => 'dependency_resolution_failed';
  @override
  DiagnosticCategory get category => DiagnosticCategory.dependency;
  @override
  String get title => 'Dependency resolution failed';
  @override
  String get description =>
      'The build output indicates that one or more dependencies could not be resolved.';
  @override
  List<String> get suggestions => const [
    'Review dependency constraints, package sources, and network access.',
  ];
  @override
  double get confidence => 0.84;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('failed to resolve') ||
        l.contains('could not resolve') ||
        l.contains('version solving failed');
  }
}

class XcodeBuildFailureRule extends BuildDoctorRule {
  const XcodeBuildFailureRule();
  @override
  String get id => 'xcode_build_failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.xcode;
  @override
  String get title => 'Xcode build failure detected';
  @override
  String get description =>
      'The output contains an Xcode build failure that requires platform-specific investigation.';
  @override
  List<String> get suggestions => const [
    'Review the first Xcode error and verify the installed Xcode and iOS SDK versions.',
  ];
  @override
  double get confidence => 0.7;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('xcodebuild') || l.contains('xcode project');
  }
}

class CocoaPodsFailureRule extends BuildDoctorRule {
  const CocoaPodsFailureRule();
  @override
  String get id => 'cocoapods_failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.cocoapods;
  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;
  @override
  String get title => 'CocoaPods issue detected';
  @override
  String get description =>
      'The output references CocoaPods and may require iOS dependency integration fixes.';
  @override
  List<String> get suggestions => const [
    'Run pod installation from the iOS directory and review the first CocoaPods error.',
  ];
  @override
  double get confidence => 0.68;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('pod install') || l.contains('cocoapods');
  }
}

class SigningConfigurationRule extends BuildDoctorRule {
  const SigningConfigurationRule();
  @override
  String get id => 'signing_configuration';
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'Signing configuration issue detected';
  @override
  String get description =>
      'The output indicates a code-signing or provisioning configuration problem.';
  @override
  List<String> get suggestions => const [
    'Check the target signing team, certificate, bundle identifier, and provisioning profile.',
  ];
  @override
  double get confidence => 0.82;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('provisioning profile') ||
        l.contains('no profiles for') ||
        l.contains('code signing');
  }
}

class MissingImportRule extends BuildDoctorRule {
  const MissingImportRule();
  @override
  String get id => 'missing_import';
  @override
  DiagnosticCategory get category => DiagnosticCategory.build;
  @override
  String get title => 'Missing import or library target';
  @override
  String get description =>
      'The Dart compiler reported a missing library URI or file import.';
  @override
  List<String> get suggestions => const [
    'Verify package dependency exports and ensure the imported file exists.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains("target of uri doesn't exist") ||
        l.contains('uri does not exist');
  }
}

class NullSafetyErrorRule extends BuildDoctorRule {
  const NullSafetyErrorRule();
  @override
  String get id => 'null_safety_error';
  @override
  DiagnosticCategory get category => DiagnosticCategory.build;
  @override
  String get title => 'Null safety type violation detected';
  @override
  String get description =>
      'The Dart compiler reported a null-safety contract violation during build.';
  @override
  List<String> get suggestions => const [
    'Check non-nullable variable assignments and null assertions.',
  ];
  @override
  double get confidence => 0.88;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('sound null safety') ||
        l.contains('type check failed on null');
  }
}

class FlutterToolFailureRule extends BuildDoctorRule {
  const FlutterToolFailureRule();
  @override
  String get id => 'flutter_tool_failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.build;
  @override
  String get title => 'Flutter CLI tool failure';
  @override
  String get description =>
      'The Flutter tool command encountered an internal execution or environment error.';
  @override
  List<String> get suggestions => const [
    'Run flutter doctor -v to inspect environment health and cache integrity.',
  ];
  @override
  double get confidence => 0.8;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('the flutter tool failed') ||
        l.contains('flutter command failed');
  }
}

class AssetErrorRule extends BuildDoctorRule {
  const AssetErrorRule();
  @override
  String get id => 'asset_error';
  @override
  DiagnosticCategory get category => DiagnosticCategory.build;
  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;
  @override
  String get title => 'Missing or unresolvable asset file';
  @override
  String get description =>
      'The Flutter tool could not locate an asset specified in pubspec.yaml.';
  @override
  List<String> get suggestions => const [
    'Verify asset file paths in pubspec.yaml and check file locations on disk.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('asset does not exist') ||
        l.contains('unable to load asset');
  }
}

class GradleFailureRule extends BuildDoctorRule {
  const GradleFailureRule();
  @override
  String get id => 'gradle_failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.gradle;
  @override
  String get title => 'Gradle task execution failure';
  @override
  String get description =>
      'An Android Gradle build task failed during compilation or packaging.';
  @override
  List<String> get suggestions => const [
    'Run build with --stacktrace or --info to inspect the failing Gradle task.',
  ];
  @override
  double get confidence => 0.82;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('execution failed for task') ||
        l.contains('gradle build failed');
  }
}

class ManifestMergeErrorRule extends BuildDoctorRule {
  const ManifestMergeErrorRule();
  @override
  String get id => 'manifest_merge_error';
  @override
  DiagnosticCategory get category => DiagnosticCategory.gradle;
  @override
  String get title => 'AndroidManifest merge conflict detected';
  @override
  String get description =>
      'The Android manifest merger failed due to conflicting attributes or permissions.';
  @override
  List<String> get suggestions => const [
    'Use tools:replace or align manifest attribute declarations across plugins.',
  ];
  @override
  double get confidence => 0.9;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('manifest merger failed') ||
        (l.contains('androidmanifest.xml') && l.contains('conflict'));
  }
}

class DesugaringErrorRule extends BuildDoctorRule {
  const DesugaringErrorRule();
  @override
  String get id => 'desugaring_error';
  @override
  DiagnosticCategory get category => DiagnosticCategory.java;
  @override
  String get title => 'Java core library desugaring issue';
  @override
  String get description =>
      'The build failed due to missing Java 8+ API desugaring configuration.';
  @override
  List<String> get suggestions => const [
    'Enable coreLibraryDesugaring in build.gradle and add com.android.tools:desugar_jdk_libs.',
  ];
  @override
  double get confidence => 0.88;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('desugaring') || l.contains('core library desugaring');
  }
}

class MultidexIssueRule extends BuildDoctorRule {
  const MultidexIssueRule();
  @override
  String get id => 'multidex_issue';
  @override
  DiagnosticCategory get category => DiagnosticCategory.gradle;
  @override
  String get title => '64k Dex method limit exceeded (Multidex required)';
  @override
  String get description =>
      'The Android app exceeded the 64,536 method limit without multi-dex enabled.';
  @override
  List<String> get suggestions => const [
    'Enable multiDexEnabled true in defaultConfig and add the multidex dependency.',
  ];
  @override
  double get confidence => 0.92;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('cannot fit requested classes in a single dex file') ||
        l.contains('multidex');
  }
}

class DeploymentTargetMismatchRule extends BuildDoctorRule {
  const DeploymentTargetMismatchRule();
  @override
  String get id => 'deployment_target_mismatch';
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;
  @override
  String get title => 'iOS deployment target mismatch';
  @override
  String get description =>
      'A Pod or plugin requires a higher iOS deployment target version than configured.';
  @override
  List<String> get suggestions => const [
    'Update IPHONEOS_DEPLOYMENT_TARGET in Podfile and Xcode project settings.',
  ];
  @override
  double get confidence => 0.84;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('deployment target') ||
        l.contains('minimum deployment target');
  }
}

class MissingSchemeRule extends BuildDoctorRule {
  const MissingSchemeRule();
  @override
  String get id => 'missing_scheme';
  @override
  DiagnosticCategory get category => DiagnosticCategory.xcode;
  @override
  String get title => 'Missing Xcode build scheme';
  @override
  String get description =>
      'The requested Xcode build scheme was not found in the project file.';
  @override
  List<String> get suggestions => const [
    'Open Xcode and ensure the scheme is marked as shared in Manage Schemes.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('scheme is not available') ||
        l.contains('missing xcode scheme');
  }
}

class SwiftCompilerErrorRule extends BuildDoctorRule {
  const SwiftCompilerErrorRule();
  @override
  String get id => 'swift_compiler_error';
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'Swift compiler error detected';
  @override
  String get description =>
      'The Swift compiler encountered a compilation error in iOS plugin code.';
  @override
  List<String> get suggestions => const [
    'Inspect Swift compilation errors and verify Swift language version compatibility.',
  ];
  @override
  double get confidence => 0.82;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('swift compiler error') ||
        l.contains('compilation emitting new swift module');
  }
}

/// Registry of Build Doctor diagnostic rules.
class BuildDoctorRuleRegistry {
  const BuildDoctorRuleRegistry({
    this.rules = const <BuildDoctorRule>[
      KotlinGradleMismatchRule(),
      DuplicateClassRule(),
      CompileErrorRule(),
      AndroidSdkMissingRule(),
      JavaRuntimeMismatchRule(),
      DependencyResolutionFailedRule(),
      XcodeBuildFailureRule(),
      CocoaPodsFailureRule(),
      SigningConfigurationRule(),
      MissingImportRule(),
      NullSafetyErrorRule(),
      FlutterToolFailureRule(),
      AssetErrorRule(),
      GradleFailureRule(),
      ManifestMergeErrorRule(),
      DesugaringErrorRule(),
      MultidexIssueRule(),
      DeploymentTargetMismatchRule(),
      MissingSchemeRule(),
      SwiftCompilerErrorRule(),
    ],
  });

  final List<BuildDoctorRule> rules;

  List<DiagnosticIssue> analyze(String cleanLog) {
    final issues = <DiagnosticIssue>[];
    for (final rule in rules) {
      if (rule.matches(cleanLog)) {
        issues.add(rule.createIssue(cleanLog));
      }
    }

    if (issues.isEmpty) {
      issues.add(
        DiagnosticIssue(
          id: 'unknown_log_pattern',
          category: DiagnosticCategory.build,
          severity: DiagnosticSeverity.low,
          title: 'No matching deterministic build issue detected',
          description:
              'The build output did not match the implemented deterministic rule set.',
          source: 'build log',
          evidence: [
            EvidenceReference(
              type: EvidenceType.log,
              label: 'build-log',
              value: cleanLog.substring(
                0,
                cleanLog.length > 220 ? 220 : cleanLog.length,
              ),
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action:
                  'Inspect the full build log and review the failing task output.',
              details:
                  'Inspect the full build log and review the failing task output.',
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: 0.25,
        ),
      );
    }

    return issues;
  }
}
