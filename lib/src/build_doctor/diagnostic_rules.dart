import '../core/models.dart';
import 'log_normalizer.dart';
import 'log_parser.dart';

abstract class DiagnosticRule {
  String get id;
  String get title;
  DiagnosticCategory get category;
  DiagnosticSeverity get defaultSeverity;
  DiagnosticConfidence get defaultConfidence;
  String get likelyCause;
  List<String> get recommendations;

  bool canBePrimary;
  bool canBeCascading;

  DiagnosticRule({this.canBePrimary = true, this.canBeCascading = false});

  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed);
}

class DiagnosticRuleCatalog {
  static final List<DiagnosticRule> allRules = [
    // Pub & Dependency Rules
    PubVersionSolvingRule(),
    IncompatibleConstraintsRule(),
    DartSdkConstraintRule(),
    FlutterSdkConstraintRule(),
    UnresolvedPackageRule(),

    // Dart Compiler Rules
    UnresolvedImportRule(),
    UndefinedIdentifierRule(),
    TypeMismatchRule(),
    MissingGeneratedFileRule(),

    // Android & Gradle Rules
    GradleDependencyResolutionRule(),
    AndroidSdkMissingRule(),
    JavaGradleIncompatibilityRule(),
    JavaAgpIncompatibilityRule(),
    AgpGradleMismatchRule(),
    KotlinGradlePluginRule(),
    AndroidManifestMergeRule(),
    AndroidDuplicateResourceRule(),

    // iOS Rules
    CocoaPodsResolutionRule(),
    CocoaPodsPodInstallRule(),
    IosDeploymentTargetRule(),
    XcodeBuildConfigRule(),
    IosSigningConfigRule(),

    // General Task Failure Catchers (Cascading candidates)
    GradleTaskFailureRule(),
  ];
}

// -----------------------------------------------------------------------------
// Pub & Dependency Rules
// -----------------------------------------------------------------------------

class PubVersionSolvingRule extends DiagnosticRule {
  PubVersionSolvingRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'PUB_VERSION_SOLVING_FAILED';
  @override
  String get title => 'Pub Dependency Version Solving Failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.pubDependency;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Package dependency version constraints cannot be resolved together by pub.';
  @override
  List<String> get recommendations => [
    'Inspect pubspec.yaml for conflicting dependency version bounds.',
    'Run "flutter pub outdated" to inspect compatible version ranges.',
    'Use "flutter pub upgrade --major-versions" or override constraints with dependency_overrides.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('Because ') &&
        (text.contains('depends on') ||
            text.contains('version solving failed')) &&
        (text.contains('which depends on') || text.contains('incompatible'))) {
      final evidenceLines = <EvidenceReference>[];
      for (final line in log.lines) {
        if (line.contains('Because ') ||
            line.contains('version solving failed') ||
            line.contains('So, ')) {
          evidenceLines.add(
            EvidenceReference(label: 'Pub Log', value: line.trim()),
          );
        }
      }

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'Pub solver failed to find a valid combination of dependencies.',
        likelyCause: likelyCause,
        evidence: evidenceLines.take(5).toList(),
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
        classificationReason:
            'Dependency version conflict is a prerequisite for build execution.',
      );
    }
    return null;
  }
}

class IncompatibleConstraintsRule extends DiagnosticRule {
  IncompatibleConstraintsRule()
    : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'PUB_INCOMPATIBLE_CONSTRAINTS';
  @override
  String get title => 'Incompatible Dependency Constraints';
  @override
  DiagnosticCategory get category => DiagnosticCategory.pubDependency;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Two or more packages require mutually exclusive versions of a shared dependency.';
  @override
  List<String> get recommendations => [
    'Check pubspec.yaml for tight constraint pins.',
    'Widen compatible version bounds for the disputed dependency.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('version solving failed') &&
        text.contains('has no versions')) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('version solving failed') ||
                l.contains('no versions'),
          )
          .map(
            (l) =>
                EvidenceReference(label: 'Constraint Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'No compatible package version satisfies constraint bounds.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class DartSdkConstraintRule extends DiagnosticRule {
  DartSdkConstraintRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'DART_SDK_CONSTRAINT_MISMATCH';
  @override
  String get title => 'Dart SDK Constraint Incompatibility';
  @override
  DiagnosticCategory get category => DiagnosticCategory.pubDependency;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'The active Dart SDK version does not satisfy the environment sdk requirement in pubspec.yaml.';
  @override
  List<String> get recommendations => [
    'Upgrade your local Dart/Flutter SDK installation.',
    'Or adjust the environment sdk bound in pubspec.yaml.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('requires SDK version') ||
        text.contains('Dart SDK version') && text.contains('is incompatible')) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('requires SDK version') ||
                l.contains('Dart SDK version'),
          )
          .map((l) => EvidenceReference(label: 'SDK Mismatch', value: l.trim()))
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'Current Dart SDK is incompatible with package environment constraints.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class FlutterSdkConstraintRule extends DiagnosticRule {
  FlutterSdkConstraintRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'FLUTTER_SDK_CONSTRAINT_MISMATCH';
  @override
  String get title => 'Flutter SDK Constraint Incompatibility';
  @override
  DiagnosticCategory get category => DiagnosticCategory.pubDependency;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'The current Flutter SDK version does not meet the minimum requirement of a dependency.';
  @override
  List<String> get recommendations => [
    'Run "flutter upgrade" to update your local Flutter framework installation.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('requires Flutter SDK version') ||
        text.contains('Flutter SDK version') && text.contains('incompatible')) {
      final evidence = log.lines
          .where((l) => l.contains('Flutter SDK'))
          .map(
            (l) =>
                EvidenceReference(label: 'Flutter SDK Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'Current Flutter SDK does not meet package requirement bounds.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class UnresolvedPackageRule extends DiagnosticRule {
  UnresolvedPackageRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'PUB_UNRESOLVED_PACKAGE';
  @override
  String get title => 'Unresolved Package Dependency';
  @override
  DiagnosticCategory get category => DiagnosticCategory.pubDependency;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'A imported package is not listed in pubspec.yaml or pub get has not been run.';
  @override
  List<String> get recommendations => [
    'Run "flutter pub get" to fetch dependencies.',
    'Ensure the package name is declared in pubspec.yaml under dependencies.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains("Target of URI doesn't exist: 'package:") ||
        text.contains("Error: Could not resolve the package")) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains("Target of URI doesn't exist: 'package:") ||
                l.contains("Could not resolve the package"),
          )
          .map(
            (l) => EvidenceReference(label: 'Package Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'Imported package could not be resolved in the package config.',
        likelyCause: likelyCause,
        evidence: evidence.take(5).toList(),
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// Dart Compiler Rules
// -----------------------------------------------------------------------------

class UnresolvedImportRule extends DiagnosticRule {
  UnresolvedImportRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'DART_UNRESOLVED_IMPORT';
  @override
  String get title => 'Unresolved Source Import';
  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Target Dart file or library URI does not exist at the specified path.';
  @override
  List<String> get recommendations => [
    'Verify the import file path in the reported Dart file.',
    'Ensure missing source files are created or moved to the correct path.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    for (final event in parsed.events) {
      if (event.rawText.contains("Target of URI doesn't exist:") &&
          !event.rawText.contains("package:")) {
        return DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary: 'Import URI could not be resolved.',
          likelyCause: likelyCause,
          filePath: event.sourceFilePath,
          line: event.sourceLineNumber,
          evidence: [
            EvidenceReference(
              label: 'Compiler Error',
              value: event.rawText.trim(),
            ),
          ],
          recommendations: recommendations
              .map((r) => FixSuggestion(action: r))
              .toList(),
          primaryStatus: PrimaryStatus.primary,
        );
      }
    }
    return null;
  }
}

class UndefinedIdentifierRule extends DiagnosticRule {
  UndefinedIdentifierRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'DART_UNDEFINED_IDENTIFIER';
  @override
  String get title => 'Undefined Class, Getter, or Method';
  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Referenced class, method, getter, setter, or identifier is not defined or imported.';
  @override
  List<String> get recommendations => [
    'Add the missing import statement.',
    'Check for typos in symbol names.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    for (final event in parsed.events) {
      if (event.rawText.contains("Undefined name ") ||
          event.rawText.contains("isn't defined for the class") ||
          event.rawText.contains("Method not found:")) {
        return DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary: 'Referenced identifier is undefined in the current scope.',
          likelyCause: likelyCause,
          filePath: event.sourceFilePath,
          line: event.sourceLineNumber,
          evidence: [
            EvidenceReference(
              label: 'Compiler Line',
              value: event.rawText.trim(),
            ),
          ],
          recommendations: recommendations
              .map((r) => FixSuggestion(action: r))
              .toList(),
          primaryStatus: PrimaryStatus.primary,
        );
      }
    }
    return null;
  }
}

class TypeMismatchRule extends DiagnosticRule {
  TypeMismatchRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'DART_TYPE_MISMATCH';
  @override
  String get title => 'Dart Type Assignment Mismatch';
  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Assigned value type does not match the declared variable or parameter type.';
  @override
  List<String> get recommendations => [
    'Check parameter types and return type signatures.',
    'Apply explicit type conversions if appropriate.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    for (final event in parsed.events) {
      if (event.rawText.contains("can't be assigned to a variable of type") ||
          event.rawText.contains("isn't a valid subtype")) {
        return DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary: 'Type mismatch in variable assignment or method call.',
          likelyCause: likelyCause,
          filePath: event.sourceFilePath,
          line: event.sourceLineNumber,
          evidence: [
            EvidenceReference(label: 'Type Error', value: event.rawText.trim()),
          ],
          recommendations: recommendations
              .map((r) => FixSuggestion(action: r))
              .toList(),
          primaryStatus: PrimaryStatus.primary,
        );
      }
    }
    return null;
  }
}

class MissingGeneratedFileRule extends DiagnosticRule {
  MissingGeneratedFileRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'DART_MISSING_GENERATED_FILE';
  @override
  String get title => 'Missing Generated Code File';
  @override
  DiagnosticCategory get category => DiagnosticCategory.dartCompiler;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'A part file (.g.dart, .freezed.dart) is referenced but build_runner has not been executed.';
  @override
  List<String> get recommendations => [
    'Run "dart run build_runner build --delete-conflicting-outputs".',
    'Verify build_runner is listed under dev_dependencies in pubspec.yaml.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('.g.dart') || text.contains('.freezed.dart')) {
      if (text.contains("Target of URI doesn't exist") ||
          text.contains("is missing part")) {
        final evidence = log.lines
            .where(
              (l) =>
                  (l.contains('.g.dart') || l.contains('.freezed.dart')) &&
                  l.contains("doesn't exist"),
            )
            .map(
              (l) => EvidenceReference(
                label: 'Missing Generated File',
                value: l.trim(),
              ),
            )
            .toList();

        return DiagnosticFinding(
          id: id,
          title: title,
          category: category,
          severity: defaultSeverity,
          confidence: defaultConfidence,
          summary:
              'Code generation file (.g.dart / .freezed.dart) is missing or stale.',
          likelyCause: likelyCause,
          evidence: evidence,
          recommendations: recommendations
              .map((r) => FixSuggestion(action: r))
              .toList(),
          primaryStatus: PrimaryStatus.primary,
        );
      }
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// Android & Gradle Rules
// -----------------------------------------------------------------------------

class GradleDependencyResolutionRule extends DiagnosticRule {
  GradleDependencyResolutionRule()
    : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'GRADLE_DEPENDENCY_RESOLUTION_FAILED';
  @override
  String get title => 'Gradle Dependency Resolution Failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.androidGradle;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'A required Maven/Gradle dependency could not be found in configured repositories or network availability failed.';
  @override
  List<String> get recommendations => [
    'Inspect the missing dependency artifact and repository URLs in android/build.gradle.',
    'Verify google(), mavenCentral(), and custom repository definitions.',
    'Check network connectivity or proxy settings for Gradle build.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('Could not resolve all dependencies for configuration') ||
        text.contains('Could not find') &&
            text.contains('Searched in the following locations:')) {
      final evidence = <EvidenceReference>[];
      for (final line in log.lines) {
        if (line.contains('Could not resolve') ||
            line.contains('Could not find') ||
            line.contains('Searched in the following locations')) {
          evidence.add(
            EvidenceReference(
              label: 'Gradle Resolution Evidence',
              value: line.trim(),
            ),
          );
        }
      }

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'Gradle failed to resolve Android dependencies from configured repositories.',
        likelyCause: likelyCause,
        evidence: evidence.take(6).toList(),
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
        classificationReason:
            'Gradle dependency resolution failure triggers downstream compilation task failures.',
      );
    }
    return null;
  }
}

class AndroidSdkMissingRule extends DiagnosticRule {
  AndroidSdkMissingRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'ANDROID_SDK_MISSING';
  @override
  String get title => 'Missing Android SDK or Platform';
  @override
  DiagnosticCategory get category => DiagnosticCategory.androidGradle;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Android SDK location or requested compileSdkVersion platform package is not installed.';
  @override
  List<String> get recommendations => [
    'Set ANDROID_HOME or ANDROID_SDK_ROOT environment variable.',
    'Open Android Studio SDK Manager and install the requested platform SDK.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('SDK location not found') ||
        text.contains('Failed to find target with hash string') ||
        text.contains('android-SDK') && text.contains('not found')) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('SDK location') ||
                l.contains('Failed to find target'),
          )
          .map(
            (l) =>
                EvidenceReference(label: 'Android SDK Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'Android SDK directory or requested API platform is missing.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class JavaGradleIncompatibilityRule extends DiagnosticRule {
  JavaGradleIncompatibilityRule()
    : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'JAVA_GRADLE_INCOMPATIBILITY';
  @override
  String get title => 'Java and Gradle Version Incompatibility';
  @override
  DiagnosticCategory get category => DiagnosticCategory.androidGradle;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'The JDK runtime version used for build execution is not supported by the current Gradle wrapper version.';
  @override
  List<String> get recommendations => [
    'Upgrade Gradle wrapper version in android/gradle/wrapper/gradle-wrapper.properties.',
    'Or switch JAVA_HOME to a compatible JDK version (e.g. Java 17).',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('Unsupported class file major version') ||
        text.contains('Java version') &&
            text.contains('is not supported by Gradle')) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('Unsupported class file') ||
                l.contains('is not supported by Gradle'),
          )
          .map(
            (l) => EvidenceReference(
              label: 'Java/Gradle Incompatibility',
              value: l.trim(),
            ),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'Active Java version is incompatible with Gradle wrapper version.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class JavaAgpIncompatibilityRule extends DiagnosticRule {
  JavaAgpIncompatibilityRule()
    : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'JAVA_AGP_INCOMPATIBILITY';
  @override
  String get title => 'Java and Android Gradle Plugin Incompatibility';
  @override
  DiagnosticCategory get category => DiagnosticCategory.androidGradle;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'The Android Gradle Plugin requires a newer Java version (such as JDK 17).';
  @override
  List<String> get recommendations => [
    'Set JAVA_HOME to JDK 17 or higher in build configuration.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('Android Gradle plugin requires Java') ||
        text.contains('compileJava task requires Java')) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('Android Gradle plugin requires Java') ||
                l.contains('compileJava'),
          )
          .map(
            (l) => EvidenceReference(label: 'AGP Java Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'Android Gradle Plugin requires a higher Java JDK version.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class AgpGradleMismatchRule extends DiagnosticRule {
  AgpGradleMismatchRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'AGP_GRADLE_VERSION_MISMATCH';
  @override
  String get title => 'AGP and Gradle Version Mismatch';
  @override
  DiagnosticCategory get category => DiagnosticCategory.androidGradle;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'The configured Android Gradle Plugin version is incompatible with Gradle.';
  @override
  List<String> get recommendations => [
    'Align AGP version in android/settings.gradle or build.gradle with compatible Gradle wrapper version.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('requires Gradle version') ||
        text.contains(
          'This version of the Android Gradle plugin requires Gradle',
        )) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('requires Gradle version') ||
                l.contains('Android Gradle plugin requires Gradle'),
          )
          .map(
            (l) => EvidenceReference(
              label: 'AGP/Gradle Mismatch',
              value: l.trim(),
            ),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'Android Gradle Plugin version does not match Gradle wrapper version bounds.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class KotlinGradlePluginRule extends DiagnosticRule {
  KotlinGradlePluginRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'KOTLIN_GRADLE_PLUGIN_MISMATCH';
  @override
  String get title => 'Kotlin Gradle Plugin Compatibility Issue';
  @override
  DiagnosticCategory get category => DiagnosticCategory.androidGradle;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Kotlin Gradle Plugin version is incompatible with Gradle or Android Gradle Plugin.';
  @override
  List<String> get recommendations => [
    'Update kotlin-gradle-plugin version in android/build.gradle.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('org.jetbrains.kotlin.jvm') &&
            text.contains('incompatible') ||
        text.contains('Kotlin build daemon') && text.contains('failed')) {
      final evidence = log.lines
          .where((l) => l.contains('kotlin') || l.contains('Kotlin'))
          .map((l) => EvidenceReference(label: 'Kotlin Error', value: l.trim()))
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'Kotlin compiler plugin version mismatch.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class AndroidManifestMergeRule extends DiagnosticRule {
  AndroidManifestMergeRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'ANDROID_MANIFEST_MERGE_FAILED';
  @override
  String get title => 'Android Manifest Merge Failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.androidGradle;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Conflicting AndroidManifest.xml elements between project and library dependencies.';
  @override
  List<String> get recommendations => [
    'Inspect Manifest Merger log output in build/app/outputs/logs/manifest-merger-log.txt.',
    'Add tools:replace attributes in AndroidManifest.xml for conflicting attributes.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('Manifest merger failed') ||
        text.contains('Attribute') && text.contains('is also present at')) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('Manifest merger failed') ||
                l.contains('is also present at'),
          )
          .map(
            (l) => EvidenceReference(
              label: 'Manifest Merge Error',
              value: l.trim(),
            ),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'AndroidManifest.xml merge failed due to conflicting attributes.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class AndroidDuplicateResourceRule extends DiagnosticRule {
  AndroidDuplicateResourceRule()
    : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'ANDROID_DUPLICATE_RESOURCE_OR_CLASS';
  @override
  String get title => 'Duplicate Android Resource or Class';
  @override
  DiagnosticCategory get category => DiagnosticCategory.androidGradle;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Multiple dependencies or source modules contain identical class or resource names.';
  @override
  List<String> get recommendations => [
    'Exclude duplicate transitive dependencies in android/app/build.gradle.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('Duplicate class') && text.contains('found in modules') ||
        text.contains('Entry name') && text.contains('collision')) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('Duplicate class') || l.contains('found in modules'),
          )
          .map(
            (l) => EvidenceReference(label: 'Duplicate Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary:
            'Duplicate Java/Kotlin class or resource detected across dependencies.',
        likelyCause: likelyCause,
        evidence: evidence.take(5).toList(),
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// iOS Rules
// -----------------------------------------------------------------------------

class CocoaPodsResolutionRule extends DiagnosticRule {
  CocoaPodsResolutionRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'COCOAPODS_RESOLUTION_FAILED';
  @override
  String get title => 'CocoaPods Dependency Resolution Failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.iosCocoaPods;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'CocoaPods could not find compatible versions for pod dependencies in Podfile.';
  @override
  List<String> get recommendations => [
    'Run "pod repo update" in the ios directory.',
    'Check platform target in ios/Podfile.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('CocoaPods could not find compatible versions') ||
        text.contains('[!] CocoaPods could not find compatible versions')) {
      final evidence = log.lines
          .where(
            (l) => l.contains('CocoaPods') || l.contains('Specs satisfying'),
          )
          .map(
            (l) => EvidenceReference(label: 'CocoaPods Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'CocoaPods pod dependency resolution failed.',
        likelyCause: likelyCause,
        evidence: evidence.take(5).toList(),
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class CocoaPodsPodInstallRule extends DiagnosticRule {
  CocoaPodsPodInstallRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'COCOAPODS_POD_INSTALL_FAILED';
  @override
  String get title => 'CocoaPods Pod Install Failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.iosCocoaPods;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Pod installation failed due to missing specs repo or invalid Podfile setup.';
  @override
  List<String> get recommendations => [
    'Run "cd ios && pod install --repo-update".',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('Error running pod install') ||
        text.contains('pod install failed')) {
      final evidence = log.lines
          .where(
            (l) => l.contains('pod install') || l.contains('Error running'),
          )
          .map(
            (l) =>
                EvidenceReference(label: 'Pod Install Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'Execution of "pod install" failed.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class IosDeploymentTargetRule extends DiagnosticRule {
  IosDeploymentTargetRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'IOS_DEPLOYMENT_TARGET_TOO_LOW';
  @override
  String get title => 'iOS Deployment Target Too Low';
  @override
  DiagnosticCategory get category => DiagnosticCategory.iosCocoaPods;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'A plugin pod requires a higher minimum iOS deployment target version than configured in Podfile.';
  @override
  List<String> get recommendations => [
    'Update platform :ios, \'13.0\' (or higher) in ios/Podfile.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('platform :ios') &&
            text.contains('higher minimum deployment target') ||
        text.contains('requires a higher minimum deployment target')) {
      final evidence = log.lines
          .where((l) => l.contains('deployment target'))
          .map(
            (l) =>
                EvidenceReference(label: 'Deployment Target', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'iOS deployment target is lower than required by plugin pods.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class XcodeBuildConfigRule extends DiagnosticRule {
  XcodeBuildConfigRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'XCODE_BUILD_CONFIG_FAILED';
  @override
  String get title => 'Xcode Build Configuration Error';
  @override
  DiagnosticCategory get category => DiagnosticCategory.iosCocoaPods;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'Xcode build settings or framework architecture linking failed.';
  @override
  List<String> get recommendations => [
    'Open ios/Runner.xcworkspace in Xcode and review build settings.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('xcodebuild: error:') ||
        text.contains('Command CompileSwift failed')) {
      final evidence = log.lines
          .where(
            (l) =>
                l.contains('xcodebuild') || l.contains('Command CompileSwift'),
          )
          .map((l) => EvidenceReference(label: 'Xcode Error', value: l.trim()))
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'Xcode native build step failed.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

class IosSigningConfigRule extends DiagnosticRule {
  IosSigningConfigRule() : super(canBePrimary: true, canBeCascading: false);

  @override
  String get id => 'IOS_SIGNING_CONFIG_MISSING';
  @override
  String get title => 'Missing iOS Code Signing Configuration';
  @override
  DiagnosticCategory get category => DiagnosticCategory.iosCocoaPods;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.high;
  @override
  String get likelyCause =>
      'No provisioning profile or signing identity was found for device build.';
  @override
  List<String> get recommendations => [
    'Select a development team in Xcode under Runner Signing & Capabilities.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('Signing for "Runner" requires a development team') ||
        text.contains('No profile was found for')) {
      final evidence = log.lines
          .where(
            (l) => l.contains('Signing') || l.contains('profile was found'),
          )
          .map(
            (l) => EvidenceReference(label: 'Signing Error', value: l.trim()),
          )
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'iOS signing team or provisioning profile is not configured.',
        likelyCause: likelyCause,
        evidence: evidence,
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.primary,
      );
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// Gradle General Task Failure (Cascading Failure Candidate)
// -----------------------------------------------------------------------------

class GradleTaskFailureRule extends DiagnosticRule {
  GradleTaskFailureRule() : super(canBePrimary: false, canBeCascading: true);

  @override
  String get id => 'GRADLE_TASK_FAILED';
  @override
  String get title => 'Gradle Task Execution Failure';
  @override
  DiagnosticCategory get category => DiagnosticCategory.generalBuild;
  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.error;
  @override
  DiagnosticConfidence get defaultConfidence => DiagnosticConfidence.medium;
  @override
  String get likelyCause =>
      'A Gradle build task failed as a downstream symptom of an earlier failure.';
  @override
  List<String> get recommendations => [
    'Inspect the primary failure root cause reported above.',
  ];

  @override
  DiagnosticFinding? match(NormalizedLog log, ParsedLogOutput parsed) {
    final text = log.normalizedContent;
    if (text.contains('BUILD FAILED in') ||
        text.contains('FAILED') && text.contains('Task :')) {
      final evidence = log.lines
          .where((l) => l.contains('FAILED') || l.contains('BUILD FAILED'))
          .map((l) => EvidenceReference(label: 'Task Failure', value: l.trim()))
          .toList();

      return DiagnosticFinding(
        id: id,
        title: title,
        category: category,
        severity: defaultSeverity,
        confidence: defaultConfidence,
        summary: 'Gradle build task terminated with failure.',
        likelyCause: likelyCause,
        evidence: evidence.take(3).toList(),
        recommendations: recommendations
            .map((r) => FixSuggestion(action: r))
            .toList(),
        primaryStatus: PrimaryStatus.cascading,
        classificationReason:
            'General task failures are typically downstream symptoms of specific compiler or dependency failures.',
      );
    }
    return null;
  }
}
