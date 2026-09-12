import '../core/models.dart';

/// Contract for deterministic build log diagnostic rules.
abstract class BuildDoctorRule {
  const BuildDoctorRule();

  /// Primary stable unique identifier.
  String get id;

  /// Human-readable title of the issue.
  String get title;

  /// Target platform category (`android`, `ios`, `dart`, `flutter`, `general`).
  String get platform => 'general';

  /// Root-cause grouping tag (e.g. `android.kotlin`, `ios.signing`).
  String? get rootCauseGroup => null;

  /// Rule priority (higher value = more specific root cause; lower = generic symptom).
  int get priority => 50;

  /// Diagnostic category.
  DiagnosticCategory get category => DiagnosticCategory.build;

  /// Diagnostic severity level.
  DiagnosticSeverity get severity => DiagnosticSeverity.high;

  /// Explanation of why this build error occurred.
  String get description;

  /// Actionable suggestions to resolve the issue.
  List<String> get suggestions;

  /// Rule confidence score (0.0 to 1.0).
  double get confidence => 0.8;

  /// Returns true if this rule matches the normalized build log.
  bool matches(String cleanLog);

  /// Extract evidence snippet from the build log.
  String extractEvidence(String cleanLog) {
    final lowerLog = cleanLog.toLowerCase();
    final key = id.replaceAll('.', ' ').replaceAll('_', ' ');
    final index = lowerLog.indexOf(key);
    if (index != -1) {
      final start = (index - 40).clamp(0, cleanLog.length);
      final end = (index + 180).clamp(0, cleanLog.length);
      return cleanLog.substring(start, end).trim();
    }
    return cleanLog.substring(0, cleanLog.length > 240 ? 240 : cleanLog.length);
  }

  /// Builds a DiagnosticIssue for this rule.
  DiagnosticIssue createIssue(
    String cleanLog, {
    List<DiagnosticIssue>? relatedSymptoms,
  }) {
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
// ANDROID BUILD RULES (20 Rules)
// ==========================================

class KotlinGradleMismatchRule extends BuildDoctorRule {
  const KotlinGradleMismatchRule();
  @override
  String get id => 'android.kotlin-mismatch';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.kotlin';
  @override
  int get priority => 90;
  @override
  String get title => 'Potential Kotlin/Gradle compatibility issue';
  @override
  String get description =>
      'The build log suggests a Kotlin compiler and Android Gradle Plugin (AGP) version compatibility mismatch.';
  @override
  List<String> get suggestions => const [
    'Verify Kotlin and Android Gradle Plugin compatibility matrix in android/build.gradle.',
    'Update org.jetbrains.kotlin.android plugin version to match your AGP version.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return (l.contains('kotlin') &&
            l.contains('gradle') &&
            l.contains('plugin')) ||
        l.contains('kotlin compiler version') ||
        l.contains('was compiled with kotlin');
  }
}

class DuplicateClassRule extends BuildDoctorRule {
  const DuplicateClassRule();
  @override
  String get id => 'android.duplicate-class';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.class_conflict';
  @override
  int get priority => 90;
  @override
  String get title => 'Duplicate class detected in Android dependencies';
  @override
  String get description =>
      'The build log indicates that the same class is included in multiple dependency modules or JARs.';
  @override
  List<String> get suggestions => const [
    'Check dependency tree using "./gradlew app:dependencies" and exclude duplicate transitive dependencies.',
  ];
  @override
  double get confidence => 0.88;
  @override
  bool matches(String cleanLog) =>
      cleanLog.toLowerCase().contains('duplicate class');
}

class AndroidSdkMissingRule extends BuildDoctorRule {
  const AndroidSdkMissingRule();
  @override
  String get id => 'android.sdk-missing';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.sdk';
  @override
  int get priority => 90;
  @override
  String get title => 'Android SDK component or ANDROID_HOME missing';
  @override
  String get description =>
      'The build output indicates that an Android SDK component or target API level could not be found.';
  @override
  List<String> get suggestions => const [
    'Install the required Android SDK platform components and verify ANDROID_HOME environment variable.',
  ];
  @override
  double get confidence => 0.87;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return (l.contains('android sdk') || l.contains('sdk location')) &&
        (l.contains('not found') ||
            l.contains('missing') ||
            l.contains('failed to find target'));
  }
}

class JavaRuntimeMismatchRule extends BuildDoctorRule {
  const JavaRuntimeMismatchRule();
  @override
  String get id => 'android.java-runtime-mismatch';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.java';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.java;
  @override
  String get title => 'Java/JDK runtime version incompatibility';
  @override
  String get description =>
      'The build output indicates an incompatible or unsupported Java runtime version.';
  @override
  List<String> get suggestions => const [
    'Verify JAVA_HOME environment variable and ensure your JDK matches AGP requirement (e.g. JDK 17 for AGP 8+).',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('java home') ||
        l.contains('unsupported class file major version') ||
        l.contains('java_home');
  }
}

class ManifestMergeErrorRule extends BuildDoctorRule {
  const ManifestMergeErrorRule();
  @override
  String get id => 'android.manifest-merger-failure';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.manifest';
  @override
  int get priority => 95;
  @override
  DiagnosticCategory get category => DiagnosticCategory.gradle;
  @override
  String get title => 'AndroidManifest merge conflict detected';
  @override
  String get description =>
      'The Android manifest merger failed due to conflicting attributes, permissions, or minSdk values across plugins.';
  @override
  List<String> get suggestions => const [
    'Add tools:replace in AndroidManifest.xml for conflicting attributes or align minSdkVersion across plugins.',
  ];
  @override
  double get confidence => 0.92;
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
  String get id => 'android.desugaring';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.java';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.java;
  @override
  String get title => 'Java 8+ core library desugaring issue';
  @override
  String get description =>
      'The build failed due to missing core library desugaring for modern Java APIs on older Android API levels.';
  @override
  List<String> get suggestions => const [
    'Enable coreLibraryDesugaringEnabled true in app/build.gradle and add com.android.tools:desugar_jdk_libs.',
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
  String get id => 'android.multidex';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.multidex';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.gradle;
  @override
  String get title => '64K Dex method limit exceeded (Multidex required)';
  @override
  String get description =>
      'The Android app exceeded the 65,536 method limit without MultiDex enabled.';
  @override
  List<String> get suggestions => const [
    'Set multiDexEnabled true in android/app/build.gradle defaultConfig.',
  ];
  @override
  double get confidence => 0.92;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('cannot fit requested classes in a single dex file') ||
        l.contains('multidex') ||
        l.contains('d8: cannot fit requested classes');
  }
}

class AndroidAgpMismatchRule extends BuildDoctorRule {
  const AndroidAgpMismatchRule();
  @override
  String get id => 'android.agp-mismatch';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.agp';
  @override
  int get priority => 90;
  @override
  String get title => 'Android Gradle Plugin (AGP) version mismatch';
  @override
  String get description =>
      'The Android Gradle Plugin version is incompatible with Gradle or the configured JDK.';
  @override
  List<String> get suggestions => const [
    'Check Gradle distribution version in gradle-wrapper.properties against AGP version in build.gradle.',
  ];
  @override
  double get confidence => 0.87;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('android gradle plugin requires') ||
        l.contains('com.android.tools.build:gradle');
  }
}

class AndroidBuildToolsMissingRule extends BuildDoctorRule {
  const AndroidBuildToolsMissingRule();
  @override
  String get id => 'android.build-tools-missing';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.sdk';
  @override
  int get priority => 85;
  @override
  String get title => 'Android SDK Build-Tools component missing';
  @override
  String get description =>
      'The specified Android SDK build-tools version is not installed on the system.';
  @override
  List<String> get suggestions => const [
    'Install the required build-tools version using Android Studio SDK Manager or sdkmanager CLI.',
  ];
  @override
  double get confidence => 0.86;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('failed to find build-tools') ||
        l.contains('build-tools revision');
  }
}

class AndroidCompileSdkMismatchRule extends BuildDoctorRule {
  const AndroidCompileSdkMismatchRule();
  @override
  String get id => 'android.compile-sdk-mismatch';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.sdk';
  @override
  int get priority => 85;
  @override
  String get title => 'Android compileSdkVersion mismatch';
  @override
  String get description =>
      'A plugin or library dependency requires a higher compileSdkVersion than configured in app/build.gradle.';
  @override
  List<String> get suggestions => const [
    'Update compileSdkVersion in android/app/build.gradle to the required API level.',
  ];
  @override
  double get confidence => 0.88;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('compilesdkversion') || l.contains('requires compilesdk');
  }
}

class AndroidDependencyResolutionFailedRule extends BuildDoctorRule {
  const AndroidDependencyResolutionFailedRule();
  @override
  String get id => 'android.dependency-resolution-failure';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.dependency';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.dependency;
  @override
  String get title => 'Android Gradle dependency resolution failed';
  @override
  String get description =>
      'One or more Gradle dependencies or Maven artifacts could not be resolved.';
  @override
  List<String> get suggestions => const [
    'Verify repository URLs (google(), mavenCentral()) and check network / proxy connectivity.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('could not resolve all files') ||
        l.contains('failed to resolve') ||
        (l.contains('could not find') &&
            l.contains('searched in the following locations'));
  }
}

class AndroidNdkMismatchRule extends BuildDoctorRule {
  const AndroidNdkMismatchRule();
  @override
  String get id => 'android.ndk-mismatch';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.ndk';
  @override
  int get priority => 85;
  @override
  String get title => 'Android NDK missing or version mismatch';
  @override
  String get description =>
      'A native C/C++ plugin requires an Android NDK version that is missing or mismatched.';
  @override
  List<String> get suggestions => const [
    'Install the required NDK version in Android SDK Manager and set ndkVersion in build.gradle.',
  ];
  @override
  double get confidence => 0.87;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('ndk at') ||
        l.contains('ndkNotConfigured') ||
        l.contains('no version of ndk matched');
  }
}

class AndroidNamespaceErrorRule extends BuildDoctorRule {
  const AndroidNamespaceErrorRule();
  @override
  String get id => 'android.namespace-error';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.namespace';
  @override
  int get priority => 85;
  @override
  String get title => 'Android Gradle namespace declaration missing';
  @override
  String get description =>
      'AGP 8.0+ requires an explicit namespace attribute in build.gradle.';
  @override
  List<String> get suggestions => const [
    'Add namespace "com.example.app" inside android {} block in build.gradle.',
  ];
  @override
  double get confidence => 0.89;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('namespace not specified') ||
        l.contains('specify a namespace');
  }
}

class AndroidResourceLinkingFailedRule extends BuildDoctorRule {
  const AndroidResourceLinkingFailedRule();
  @override
  String get id => 'android.resource-linking-failed';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.resource';
  @override
  int get priority => 85;
  @override
  String get title => 'Android AAPT2 resource linking failure';
  @override
  String get description =>
      'AAPT2 failed to link XML layout resources, drawables, or values.';
  @override
  List<String> get suggestions => const [
    'Check XML syntax in res/ values, styles, and drawable files for duplicate or missing resource IDs.',
  ];
  @override
  double get confidence => 0.86;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('aapt2 error') || l.contains('resource linking failed');
  }
}

class AndroidMissingResourceRule extends BuildDoctorRule {
  const AndroidMissingResourceRule();
  @override
  String get id => 'android.missing-resource';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.resource';
  @override
  int get priority => 80;
  @override
  String get title => 'Missing Android drawable or asset resource';
  @override
  String get description =>
      'The Android compiler could not resolve a referenced resource entry.';
  @override
  List<String> get suggestions => const [
    'Ensure the referenced resource file exists in android/app/src/main/res/.',
  ];
  @override
  double get confidence => 0.84;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('resource top-level element is invalid') ||
        l.contains('no resource found that matches the given name');
  }
}

class AndroidPluginCompilationErrorRule extends BuildDoctorRule {
  const AndroidPluginCompilationErrorRule();
  @override
  String get id => 'android.plugin-compilation-error';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.plugin';
  @override
  int get priority => 80;
  @override
  String get title => 'Android plugin Java/Kotlin compilation error';
  @override
  String get description =>
      'A Flutter plugin\'s Android native Java or Kotlin code failed to compile.';
  @override
  List<String> get suggestions => const [
    'Check plugin dependency compatibility in pubspec.yaml and update the failing plugin to its latest release.',
  ];
  @override
  double get confidence => 0.82;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('compilation failed for task \':') &&
        l.contains('compilekotlin');
  }
}

class AndroidSigningConfigurationRule extends BuildDoctorRule {
  const AndroidSigningConfigurationRule();
  @override
  String get id => 'android.signing-configuration';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.signing';
  @override
  int get priority => 90;
  @override
  String get title => 'Android keystore or signing configuration error';
  @override
  String get description =>
      'The release APK/AAB build failed due to missing or invalid keystore credentials.';
  @override
  List<String> get suggestions => const [
    'Verify storeFile, storePassword, and keyPassword in key.properties and build.gradle.',
  ];
  @override
  double get confidence => 0.88;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('keystore file not found') ||
        l.contains('failed to read key') ||
        l.contains('signingconfig');
  }
}

class AndroidR8ProguardFailureRule extends BuildDoctorRule {
  const AndroidR8ProguardFailureRule();
  @override
  String get id => 'android.r8-proguard-failure';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.r8';
  @override
  int get priority => 85;
  @override
  String get title => 'R8/ProGuard minification failure';
  @override
  String get description =>
      'R8 code shrinking failed due to missing keep rules or missing class references.';
  @override
  List<String> get suggestions => const [
    'Add required -dontwarn or -keep rules to proguard-rules.pro.',
  ];
  @override
  double get confidence => 0.87;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('r8:') ||
        l.contains('proguard') ||
        l.contains('missing class');
  }
}

class AndroidGradleDaemonFailureRule extends BuildDoctorRule {
  const AndroidGradleDaemonFailureRule();
  @override
  String get id => 'android.gradle-daemon-failure';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.gradle';
  @override
  int get priority => 75;
  @override
  String get title => 'Gradle daemon or memory lock error';
  @override
  String get description =>
      'The Gradle daemon crashed or failed due to OutOfMemoryError or locked files.';
  @override
  List<String> get suggestions => const [
    'Run "./gradlew --stop" and increase org.gradle.jvmargs in gradle.properties.',
  ];
  @override
  double get confidence => 0.82;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('gradle daemon disappeared') ||
        l.contains('java.lang.outofmemoryerror: java heap space');
  }
}

class GradleFailureRule extends BuildDoctorRule {
  const GradleFailureRule();
  @override
  String get id => 'android.gradle-failure';
  @override
  String get platform => 'android';
  @override
  String get rootCauseGroup => 'android.gradle';
  @override
  int get priority => 20;
  @override
  DiagnosticCategory get category => DiagnosticCategory.gradle;
  @override
  String get title => 'Gradle task execution failure';
  @override
  String get description =>
      'An Android Gradle task failed during compilation or assembly.';
  @override
  List<String> get suggestions => const [
    'Run build with --stacktrace or --info to inspect the specific failing Gradle task.',
  ];
  @override
  double get confidence => 0.75;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('execution failed for task') ||
        l.contains('gradle build failed');
  }
}

// ==========================================
// IOS BUILD RULES (13 Rules)
// ==========================================

class XcodeBuildFailureRule extends BuildDoctorRule {
  const XcodeBuildFailureRule();
  @override
  String get id => 'ios.xcode-build-failure';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.xcode';
  @override
  int get priority => 20;
  @override
  DiagnosticCategory get category => DiagnosticCategory.xcode;
  @override
  String get title => 'Xcode build failure detected';
  @override
  String get description =>
      'The build log contains an Xcode build failure requiring platform investigation.';
  @override
  List<String> get suggestions => const [
    'Review the first Xcode error in Runner.xcworkspace and check Xcode toolchain versions.',
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
  String get id => 'ios.cocoapods-failure';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.cocoapods';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.cocoapods;
  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;
  @override
  String get title => 'CocoaPods installation failure';
  @override
  String get description =>
      'The iOS dependency manager (CocoaPods) failed during pod install or pod repo update.';
  @override
  List<String> get suggestions => const [
    'Run "cd ios && pod install --repo-update" to resolve CocoaPods dependencies.',
  ];
  @override
  double get confidence => 0.82;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('pod install') ||
        l.contains('cocoapods') ||
        l.contains('pod error');
  }
}

class SigningConfigurationRule extends BuildDoctorRule {
  const SigningConfigurationRule();
  @override
  String get id => 'ios.signing-configuration';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.signing';
  @override
  int get priority => 90;
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'iOS code signing or provisioning profile error';
  @override
  String get description =>
      'The iOS build failed due to missing provisioning profiles or signing team identity configuration.';
  @override
  List<String> get suggestions => const [
    'Open ios/Runner.xcworkspace in Xcode and select a valid Development Team and Provisioning Profile under Signing & Capabilities.',
  ];
  @override
  double get confidence => 0.88;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('provisioning profile') ||
        l.contains('no profiles for') ||
        l.contains('code signing') ||
        l.contains('codesign failed');
  }
}

class DeploymentTargetMismatchRule extends BuildDoctorRule {
  const DeploymentTargetMismatchRule();
  @override
  String get id => 'ios.deployment-target-mismatch';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.deployment';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'iOS minimum deployment target mismatch';
  @override
  String get description =>
      'A CocoaPod or plugin requires a higher iOS deployment target version than configured in Podfile.';
  @override
  List<String> get suggestions => const [
    'Increase platform :ios, \'13.0\' in ios/Podfile and Xcode target settings.',
  ];
  @override
  double get confidence => 0.87;
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
  String get id => 'ios.missing-scheme';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.xcode';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.xcode;
  @override
  String get title => 'Missing Xcode build scheme';
  @override
  String get description =>
      'The requested Xcode build scheme is missing or not marked as Shared.';
  @override
  List<String> get suggestions => const [
    'Open Xcode > Manage Schemes and check the Shared checkbox next to Runner.',
  ];
  @override
  double get confidence => 0.86;
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
  String get id => 'ios.swift-compiler-error';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.swift';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'Swift compiler error detected';
  @override
  String get description =>
      'The Swift compiler encountered a syntax or type error in iOS plugin code.';
  @override
  List<String> get suggestions => const [
    'Check Swift language version compatibility in Xcode and update the failing iOS plugin.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('swift compiler error') ||
        l.contains('compilation emitting new swift module');
  }
}

class ObjcCompilerErrorRule extends BuildDoctorRule {
  const ObjcCompilerErrorRule();
  @override
  String get id => 'ios.objc-compiler-error';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.objc';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'Objective-C compiler error detected';
  @override
  String get description =>
      'Clang encountered an Objective-C compilation error in an iOS plugin or header.';
  @override
  List<String> get suggestions => const [
    'Inspect Clang compilation error details and check Objective-C header imports.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('clang: error:') || l.contains('objective-c');
  }
}

class PodVersionConflictRule extends BuildDoctorRule {
  const PodVersionConflictRule();
  @override
  String get id => 'ios.pod-version-conflict';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.cocoapods';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.cocoapods;
  @override
  String get title => 'CocoaPods version specs conflict';
  @override
  String get description =>
      'CocoaPods could not find compatible versions for transitive pod dependencies.';
  @override
  List<String> get suggestions => const [
    'Run "pod update" in the ios/ directory to refresh Podfile.lock dependency specs.',
  ];
  @override
  double get confidence => 0.86;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('cocoapods could not find compatible versions') ||
        l.contains('specs-satisfying');
  }
}

class IosFrameworkLinkingErrorRule extends BuildDoctorRule {
  const IosFrameworkLinkingErrorRule();
  @override
  String get id => 'ios.framework-linking-error';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.linking';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'iOS framework linking or undefined symbol error';
  @override
  String get description =>
      'The Apple LLVM linker (ld) failed to find symbols or static framework binaries.';
  @override
  List<String> get suggestions => const [
    'Verify framework search paths in Xcode and re-run "pod install".',
  ];
  @override
  double get confidence => 0.87;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('undefined symbols for architecture') ||
        l.contains('linker command failed');
  }
}

class IosModuleImportErrorRule extends BuildDoctorRule {
  const IosModuleImportErrorRule();
  @override
  String get id => 'ios.module-import-error';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.import';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'iOS module or header file import missing';
  @override
  String get description =>
      'The Swift or Clang compiler could not locate a required iOS framework module or header file.';
  @override
  List<String> get suggestions => const [
    'Ensure the iOS plugin is correctly registered and run "flutter build ios" to regenerate module maps.',
  ];
  @override
  double get confidence => 0.86;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('no such module') || l.contains('header file not found');
  }
}

class IosArchitectureIncompatibilityRule extends BuildDoctorRule {
  const IosArchitectureIncompatibilityRule();
  @override
  String get id => 'ios.architecture-incompatibility';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.arch';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'iOS simulator/device architecture mismatch';
  @override
  String get description =>
      'The build failed due to architecture mismatches (arm64 vs x86_64) between iOS Simulator and physical device binaries.';
  @override
  List<String> get suggestions => const [
    'Check ONLY_ACTIVE_ARCH and EXCLUDED_ARCHS in Xcode target build settings.',
  ];
  @override
  double get confidence => 0.88;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains(
          'building for ios simulator, but linking in object file built for ios',
        ) ||
        l.contains(
          'could not find module for target \'x86_64-apple-ios-simulator\'',
        );
  }
}

class IosBitcodeMetalErrorRule extends BuildDoctorRule {
  const IosBitcodeMetalErrorRule();
  @override
  String get id => 'ios.bitcode-metal-error';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.build';
  @override
  int get priority => 80;
  @override
  DiagnosticCategory get category => DiagnosticCategory.ios;
  @override
  String get title => 'iOS Bitcode compilation error';
  @override
  String get description =>
      'The build failed during iOS Bitcode generation (deprecated in recent Xcode versions).';
  @override
  List<String> get suggestions => const [
    'Set ENABLE_BITCODE = NO in Xcode project settings.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('bitcode') && l.contains('failed');
  }
}

class CocoaPodsRepoUpdateRule extends BuildDoctorRule {
  const CocoaPodsRepoUpdateRule();
  @override
  String get id => 'ios.cocoapods-repo-update';
  @override
  String get platform => 'ios';
  @override
  String get rootCauseGroup => 'ios.cocoapods';
  @override
  int get priority => 80;
  @override
  DiagnosticCategory get category => DiagnosticCategory.cocoapods;
  @override
  String get title => 'CocoaPods master spec repo out of date';
  @override
  String get description =>
      'CocoaPods specs on your machine are outdated and cannot find recently released pod specs.';
  @override
  List<String> get suggestions => const [
    'Run "pod repo update" to fetch the latest pod specs.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('pod repo update') || l.contains('cocoapods master repo');
  }
}

// ==========================================
// DART & FLUTTER TOOLING RULES (8 Rules)
// ==========================================

class CompileErrorRule extends BuildDoctorRule {
  const CompileErrorRule();
  @override
  String get id => 'dart.compile-error';
  @override
  String get platform => 'dart';
  @override
  String get rootCauseGroup => 'dart.compile';
  @override
  int get priority => 30;
  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;
  @override
  String get title => 'Dart compilation error detected';
  @override
  String get description =>
      'The Dart compiler encountered a syntax or type error during compilation.';
  @override
  List<String> get suggestions => const [
    'Review the exact line number in the compile error and fix Dart code syntax or types.',
  ];
  @override
  double get confidence => 0.75;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('cannot find symbol') ||
        l.contains('undefined identifier') ||
        l.contains('compilation failed');
  }
}

class MissingImportRule extends BuildDoctorRule {
  const MissingImportRule();
  @override
  String get id => 'dart.missing-import';
  @override
  String get platform => 'dart';
  @override
  String get rootCauseGroup => 'dart.import';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.build;
  @override
  String get title => 'Missing Dart import or library URI';
  @override
  String get description =>
      'The Dart compiler reported a target URI or import path that does not exist.';
  @override
  List<String> get suggestions => const [
    'Verify pubspec.yaml dependencies and check that the imported file exists on disk.',
  ];
  @override
  double get confidence => 0.88;
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
  String get id => 'dart.null-safety-error';
  @override
  String get platform => 'dart';
  @override
  String get rootCauseGroup => 'dart.null_safety';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.build;
  @override
  String get title => 'Null safety type violation detected';
  @override
  String get description =>
      'The Dart compiler reported a sound null-safety type assertion violation.';
  @override
  List<String> get suggestions => const [
    'Check non-nullable variable assignments and add null checks or non-null assertions.',
  ];
  @override
  double get confidence => 0.89;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('sound null safety') ||
        l.contains('type check failed on null');
  }
}

class DartUndefinedIdentifierRule extends BuildDoctorRule {
  const DartUndefinedIdentifierRule();
  @override
  String get id => 'dart.undefined-identifier';
  @override
  String get platform => 'dart';
  @override
  String get rootCauseGroup => 'dart.compile';
  @override
  int get priority => 80;
  @override
  String get title => 'Undefined name or identifier in Dart code';
  @override
  String get description =>
      'The Dart compiler could not resolve a class, variable, or method identifier.';
  @override
  List<String> get suggestions => const [
    'Ensure the identifier is declared and import the defining library file.',
  ];
  @override
  double get confidence => 0.86;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains("undefined name") ||
        l.contains("isn't defined for the class");
  }
}

class DartAnalyzerErrorRule extends BuildDoctorRule {
  const DartAnalyzerErrorRule();
  @override
  String get id => 'dart.analyzer-error';
  @override
  String get platform => 'dart';
  @override
  String get rootCauseGroup => 'dart.analyzer';
  @override
  int get priority => 80;
  @override
  String get title => 'Dart static analyzer error';
  @override
  String get description =>
      'Static analysis failed with severe linter or language specification violations.';
  @override
  List<String> get suggestions => const [
    'Run "flutter analyze" locally to inspect and fix reported errors.',
  ];
  @override
  double get confidence => 0.84;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('analyzer failed') || l.contains('error •');
  }
}

class FlutterToolFailureRule extends BuildDoctorRule {
  const FlutterToolFailureRule();
  @override
  String get id => 'flutter.flutter-tool-failure';
  @override
  String get platform => 'flutter';
  @override
  String get rootCauseGroup => 'flutter.tool';
  @override
  int get priority => 15;
  @override
  DiagnosticCategory get category => DiagnosticCategory.build;
  @override
  String get title => 'Flutter CLI tool failure';
  @override
  String get description =>
      'The Flutter command-line tool encountered an unexpected internal error.';
  @override
  List<String> get suggestions => const [
    'Run "flutter doctor -v" to verify toolchain health and clean build artifacts with "flutter clean".',
  ];
  @override
  double get confidence => 0.75;
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
  String get id => 'flutter.asset-error';
  @override
  String get platform => 'flutter';
  @override
  String get rootCauseGroup => 'flutter.asset';
  @override
  int get priority => 85;
  @override
  DiagnosticCategory get category => DiagnosticCategory.build;
  @override
  DiagnosticSeverity get severity => DiagnosticSeverity.medium;
  @override
  String get title => 'Missing or unresolvable asset file';
  @override
  String get description =>
      'The Flutter build tool could not locate an asset file specified in pubspec.yaml.';
  @override
  List<String> get suggestions => const [
    'Verify asset file paths in pubspec.yaml and verify the files exist on disk.',
  ];
  @override
  double get confidence => 0.87;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('asset does not exist') ||
        l.contains('unable to load asset');
  }
}

class FlutterPluginRegistrationFailureRule extends BuildDoctorRule {
  const FlutterPluginRegistrationFailureRule();
  @override
  String get id => 'flutter.plugin-registration-failure';
  @override
  String get platform => 'flutter';
  @override
  String get rootCauseGroup => 'flutter.plugin';
  @override
  int get priority => 80;
  @override
  String get title => 'Flutter plugin auto-registration failure';
  @override
  String get description =>
      'GeneratedPluginRegistrant failed to register platform plugins.';
  @override
  List<String> get suggestions => const [
    'Run "flutter pub get" and rebuild the project to regenerate GeneratedPluginRegistrant.',
  ];
  @override
  double get confidence => 0.85;
  @override
  bool matches(String cleanLog) {
    final l = cleanLog.toLowerCase();
    return l.contains('generatedpluginregistrant') ||
        l.contains('failed to register plugin');
  }
}

// ==========================================
// BUILD DOCTOR RULE REGISTRY & DEDUPLICATION
// ==========================================

/// Registry holding active build log diagnostic rules.
class BuildDoctorRuleRegistry {
  const BuildDoctorRuleRegistry({
    this.rules = const <BuildDoctorRule>[
      // Android Rules
      KotlinGradleMismatchRule(),
      DuplicateClassRule(),
      AndroidSdkMissingRule(),
      JavaRuntimeMismatchRule(),
      ManifestMergeErrorRule(),
      DesugaringErrorRule(),
      MultidexIssueRule(),
      AndroidAgpMismatchRule(),
      AndroidBuildToolsMissingRule(),
      AndroidCompileSdkMismatchRule(),
      AndroidDependencyResolutionFailedRule(),
      AndroidNdkMismatchRule(),
      AndroidNamespaceErrorRule(),
      AndroidResourceLinkingFailedRule(),
      AndroidMissingResourceRule(),
      AndroidPluginCompilationErrorRule(),
      AndroidSigningConfigurationRule(),
      AndroidR8ProguardFailureRule(),
      AndroidGradleDaemonFailureRule(),
      GradleFailureRule(),

      // iOS Rules
      XcodeBuildFailureRule(),
      CocoaPodsFailureRule(),
      SigningConfigurationRule(),
      DeploymentTargetMismatchRule(),
      MissingSchemeRule(),
      SwiftCompilerErrorRule(),
      ObjcCompilerErrorRule(),
      PodVersionConflictRule(),
      IosFrameworkLinkingErrorRule(),
      IosModuleImportErrorRule(),
      IosArchitectureIncompatibilityRule(),
      IosBitcodeMetalErrorRule(),
      CocoaPodsRepoUpdateRule(),

      // Dart & Flutter Rules
      CompileErrorRule(),
      MissingImportRule(),
      NullSafetyErrorRule(),
      DartUndefinedIdentifierRule(),
      DartAnalyzerErrorRule(),
      FlutterToolFailureRule(),
      AssetErrorRule(),
      FlutterPluginRegistrationFailureRule(),
    ],
  });

  final List<BuildDoctorRule> rules;

  /// Analyzes a clean log and returns deduplicated, prioritized issues.
  List<DiagnosticIssue> analyze(String cleanLog) {
    final matches = <BuildDoctorRule>[];
    for (final rule in rules) {
      if (rule.matches(cleanLog)) {
        matches.add(rule);
      }
    }

    if (matches.isEmpty) {
      return const <DiagnosticIssue>[];
    }

    // Sort matching rules by priority descending
    matches.sort((a, b) => b.priority.compareTo(a.priority));

    // Deduplication: If a high priority root-cause rule matched (> 70),
    // suppress generic derivative symptom rules (priority <= 30) from the same platform
    final hasHighPriorityRootCause = matches.any((r) => r.priority > 70);
    final filteredRules = <BuildDoctorRule>[];

    for (final rule in matches) {
      if (hasHighPriorityRootCause && rule.priority <= 30) {
        // Suppress generic symptom
        continue;
      }
      filteredRules.add(rule);
    }

    final issues = <DiagnosticIssue>[];
    for (final rule in filteredRules) {
      issues.add(rule.createIssue(cleanLog));
    }

    return issues;
  }
}
