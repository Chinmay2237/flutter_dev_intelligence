# Diagnostic Rules Catalog

`flutter_dev_intelligence` uses deterministic, evidence-backed rules to analyze Flutter and Dart build logs.

---

## 1. Pub & Dependency Resolution Rules

### `PUB_VERSION_SOLVING_FAILED`
* **Title:** Pub Dependency Version Solving Failure
* **Category:** Pub & Dependency Resolution
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause
* **Detection Pattern:** Log contains `Because ... depends on ... version solving failed`.
* **Likely Cause:** Package dependency version bounds cannot be resolved together by pub solver.
* **Recommendations:**
  1. Inspect `pubspec.yaml` for conflicting dependency bounds.
  2. Run `flutter pub outdated` to inspect compatible version ranges.
  3. Use `dependency_overrides` if temporary version unblocking is required.

### `PUB_INCOMPATIBLE_CONSTRAINTS`
* **Title:** Incompatible Dependency Constraints
* **Category:** Pub & Dependency Resolution
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause
* **Detection Pattern:** Log contains `version solving failed` and `has no versions`.

### `DART_SDK_CONSTRAINT_MISMATCH`
* **Title:** Dart SDK Constraint Incompatibility
* **Category:** Pub & Dependency Resolution
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause
* **Detection Pattern:** Log contains `requires SDK version` or `Dart SDK version ... is incompatible`.

### `FLUTTER_SDK_CONSTRAINT_MISMATCH`
* **Title:** Flutter SDK Constraint Incompatibility
* **Category:** Pub & Dependency Resolution
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

### `PUB_UNRESOLVED_PACKAGE`
* **Title:** Unresolved Package Dependency
* **Category:** Pub & Dependency Resolution
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

---

## 2. Dart Compiler Rules

### `DART_UNRESOLVED_IMPORT`
* **Title:** Unresolved Source Import
* **Category:** Dart Compiler
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause
* **Detection Pattern:** `Target of URI doesn't exist: '<file>.dart'`.

### `DART_UNDEFINED_IDENTIFIER`
* **Title:** Undefined Class, Getter, or Method
* **Category:** Dart Compiler
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

### `DART_TYPE_MISMATCH`
* **Title:** Dart Type Assignment Mismatch
* **Category:** Dart Compiler
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

### `DART_MISSING_GENERATED_FILE`
* **Title:** Missing Generated Code File
* **Category:** Dart Compiler
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause
* **Detection Pattern:** Missing `.g.dart` or `.freezed.dart` part files.

---

## 3. Android & Gradle Rules

### `GRADLE_DEPENDENCY_RESOLUTION_FAILED`
* **Title:** Gradle Dependency Resolution Failure
* **Category:** Android & Gradle
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause
* **Detection Pattern:** `Could not resolve all dependencies for configuration` or `Could not find ... Searched in the following locations`.

### `ANDROID_SDK_MISSING`
* **Title:** Missing Android SDK or Platform
* **Category:** Android & Gradle
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

### `JAVA_GRADLE_INCOMPATIBILITY`
* **Title:** Java and Gradle Version Incompatibility
* **Category:** Android & Gradle
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause
* **Detection Pattern:** `Unsupported class file major version` or `Java version ... is not supported by Gradle`.

### `JAVA_AGP_INCOMPATIBILITY`
* **Title:** Java and AGP Incompatibility
* **Category:** Android & Gradle
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

### `AGP_GRADLE_VERSION_MISMATCH`
* **Title:** AGP and Gradle Version Mismatch
* **Category:** Android & Gradle
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

### `ANDROID_MANIFEST_MERGE_FAILED`
* **Title:** Android Manifest Merge Failure
* **Category:** Android & Gradle
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

---

## 4. iOS & CocoaPods Rules

### `COCOAPODS_RESOLUTION_FAILED`
* **Title:** CocoaPods Dependency Resolution Failure
* **Category:** iOS & CocoaPods
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

### `IOS_DEPLOYMENT_TARGET_TOO_LOW`
* **Title:** iOS Deployment Target Too Low
* **Category:** iOS & CocoaPods
* **Default Severity:** Error
* **Default Confidence:** High
* **Primary / Cascading:** Primary Root Cause

---

## 5. General Task Failures (Cascading Candidates)

### `GRADLE_TASK_FAILED`
* **Title:** Gradle Task Execution Failure
* **Category:** General Build Failure
* **Default Severity:** Error
* **Default Confidence:** Medium
* **Primary / Cascading:** Cascading Secondary Failure
* **Classification Reason:** When an upstream dependency resolution error or compiler error exists in the build log, general task failure outputs (such as `Task :app:compileDebugJavaWithJavac FAILED` or `BUILD FAILED`) are automatically classified as cascading downstream symptoms.
