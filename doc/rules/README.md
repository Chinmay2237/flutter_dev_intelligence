# Rule Catalog (`flutter_dev_intelligence`)

This document lists all deterministic diagnostic rules implemented in `flutter_dev_intelligence` version `1.0.0`.

---

## Table of Contents

- [UI AST Diagnostic Rules (17 Rules)](#ui-ast-diagnostic-rules-17-rules)
- [Build Log Diagnostic Rules (40 Rules)](#build-log-diagnostic-rules-40-rules)
- [Performance Diagnostics (7 Metrics & Threshold Checks)](#performance-diagnostics-7-metrics--threshold-checks)

---

## UI AST Diagnostic Rules (17 Rules)

UI rules parse Dart widget source code into AST compilation units and check structural patterns, layout constraints, lifecycle cleanup, and accessibility.

### 1. `ui.nested-scrollable`
- **Title**: Unmitigated same-axis nested scrollable widget
- **Category**: Layout
- **Default Severity**: High
- **Confidence**: 0.95
- **Detects**: Same-direction scrollables (e.g. vertical `ListView` inside vertical `SingleChildScrollView`) without scroll physics mitigation.
- **Does NOT Detect**: Cross-axis scrollables (horizontal `ListView` inside vertical container) or scrollables with `NeverScrollableScrollPhysics`.
- **Example**:
  ```dart
  SingleChildScrollView(
    child: Column(children: [ListView(...)])
  )
  ```
- **Recommendation**: Add `physics: const NeverScrollableScrollPhysics()` and `shrinkWrap: true` to inner scrollable, or use `CustomScrollView` with slivers.

### 2. `ui.nested-shrink-wrap`
- **Title**: Unconstrained shrinkWrap usage on nested scrollable
- **Category**: Layout / Performance
- **Default Severity**: Medium
- **Confidence**: 0.85
- **Detects**: `shrinkWrap: true` on scrollables nested inside unbounded layout containers.
- **Recommendation**: Provide explicit parent constraints (`SizedBox`, `Expanded`) or refactor to sliver lists.

### 3. `ui.unconstrained-scrollable`
- **Title**: Unconstrained scrollable widget inside flex layout
- **Category**: Layout
- **Default Severity**: High
- **Confidence**: 0.90
- **Detects**: Scrollable widget placed directly inside a `Column` or `Row` without `Expanded`, `Flexible`, or explicit height/width constraints.
- **Recommendation**: Wrap inner scrollable in `Expanded` or `Flexible`.

### 4. `ui.expanded-misuse`
- **Title**: Expanded widget used outside Row, Column, or Flex
- **Category**: Layout
- **Default Severity**: High
- **Confidence**: 0.95
- **Detects**: `Expanded` placed directly inside `Stack`, `Container`, `Padding`, or `SingleChildScrollView`.
- **Recommendation**: Remove `Expanded` or wrap parent container with `Row`, `Column`, or `Flex`.

### 5. `ui.positioned-misuse`
- **Title**: Positioned widget used outside Stack
- **Category**: Layout
- **Default Severity**: High
- **Confidence**: 0.95
- **Detects**: `Positioned` widget whose direct parent is not a `Stack`.
- **Recommendation**: Wrap parent with `Stack` or replace `Positioned` with `Padding` or `Align`.

### 6. `ui.oversized-dimension`
- **Title**: Hardcoded dimension exceeds viewport safety threshold
- **Category**: Layout / Responsiveness
- **Default Severity**: Medium
- **Confidence**: 0.80
- **Detects**: Hardcoded `width` or `height` values exceeding 1,000 logical pixels on `SizedBox` or `Container`.
- **Recommendation**: Use relative layout sizing (`MediaQuery`, `LayoutBuilder`, or `Expanded`).

### 7. `ui.unbounded-dimension`
- **Title**: Unbounded layout container in scrollable hierarchy
- **Category**: Layout
- **Default Severity**: High
- **Confidence**: 0.88
- **Detects**: Unbounded containers causing infinite layout height errors.
- **Recommendation**: Apply `BoxConstraints` or `Flexible` wrappers.

### 8. `ui.nested-scaffold`
- **Title**: Suspicious nested Scaffold hierarchy
- **Category**: Architecture
- **Default Severity**: Medium
- **Confidence**: 0.85
- **Detects**: `Scaffold` widget nested directly inside another `Scaffold` body.
- **Recommendation**: Use a single root `Scaffold` per screen route.

### 9. `ui.build.setstate`
- **Title**: Direct setState invocation inside build method
- **Category**: Performance / State Management
- **Default Severity**: High
- **Confidence**: 0.95
- **Detects**: `setState()` invoked directly in the root body of a `build()` method (causing infinite rebuild loops).
- **Does NOT Detect**: `setState()` inside callback functions (e.g. `onTap: () => setState(...)`).
- **Recommendation**: Move state mutations into event handlers or lifecycle methods (`initState`).

### 10. `ui.build.expensive-operation`
- **Title**: Heavy computation or I/O inside build method
- **Category**: Performance
- **Default Severity**: Medium
- **Confidence**: 0.82
- **Detects**: Direct synchronous file reads, regex compilation in loops, or heavy JSON decoding inside `build()`.
- **Recommendation**: Pre-compute heavy operations outside `build()` or use `FutureBuilder` / state management.

### 11. `ui.eager-large-list`
- **Title**: Eager children list instantiation for large dataset
- **Category**: Performance
- **Default Severity**: Medium
- **Confidence**: 0.80
- **Detects**: `ListView(children: [...])` or `Column` rendering large inline child arrays.
- **Recommendation**: Use `ListView.builder` for lazy widget creation.

### 12. `ui.accessibility.unlabeled-interactive`
- **Title**: Interactive button missing accessibility label
- **Category**: Accessibility
- **Default Severity**: Low
- **Confidence**: 0.75
- **Detects**: `IconButton`, `InkWell`, or `GestureDetector` missing `tooltip` or `Semantics` label.
- **Recommendation**: Add a descriptive `tooltip` or wrap with `Semantics(label: ...)`.

### 13. `ui.accessibility.unlabeled-form-field`
- **Title**: Form field missing semantics or label text
- **Category**: Accessibility
- **Default Severity**: Low
- **Confidence**: 0.75
- **Detects**: `TextField` or `TextFormField` without `labelText` or `hintText`.
- **Recommendation**: Provide `InputDecoration(labelText: ...)`.

### 14. `ui.lifecycle.undisposed-controller`
- **Title**: Owned controller missing dispose cleanup
- **Category**: Resource Management
- **Default Severity**: High
- **Confidence**: 0.88
- **Detects**: `AnimationController`, `ScrollController`, `TextEditingController`, `FocusNode`, `PageController`, or `TabController` created in `State` without corresponding `dispose()` call.
- **Does NOT Detect**: Controllers injected via constructor or external dependency providers.
- **Recommendation**: Override `dispose()` and call `controller.dispose()`.

### 15. `ui.lifecycle.undisposed-subscription`
- **Title**: StreamSubscription or Timer missing cancellation
- **Category**: Resource Management
- **Default Severity**: Medium
- **Confidence**: 0.85
- **Detects**: `StreamSubscription.listen` or `Timer.periodic` held in state without `cancel()` in `dispose()`.
- **Recommendation**: Cancel active subscriptions in `dispose()`.

### 16. `ui.async.mounted-guard`
- **Title**: BuildContext dereferenced across async gap without mounted check
- **Category**: Async Lifecycle Safety
- **Default Severity**: Medium
- **Confidence**: 0.85
- **Detects**: `Navigator.of(context)` or `ScaffoldMessenger.of(context)` after an `await` statement without `if (!mounted) return;`.
- **Recommendation**: Add `if (!context.mounted) return;` immediately after `await`.

### 17. `ui.performance.suggestions`
- **Title**: General Flutter UI performance optimization suggestion
- **Category**: Performance
- **Default Severity**: Info
- **Confidence**: 0.70
- **Detects**: Non-const widget instantiations in static subtrees.
- **Recommendation**: Add `const` modifiers where applicable.

---

## Build Log Diagnostic Rules (40 Rules)

Deterministic build rules analyze log output from Android, iOS, Gradle, Xcode, and CI runners.

### Android Platform Rules (20 Rules)
1. `android.kotlin-mismatch`: Kotlin/AGP version mismatch.
2. `android.duplicate-class`: Duplicate class conflict across JAR dependencies.
3. `android.sdk-missing`: Missing Android SDK API component or ANDROID_HOME.
4. `android.java-runtime-mismatch`: Incompatible Java major runtime version (e.g. Java 8 vs Java 17).
5. `android.manifest-merger-failure`: AndroidManifest XML attribute conflict.
6. `android.desugaring`: Java 8+ core library desugaring error on lower API levels.
7. `android.multidex`: 64K method limit exceeded without MultiDex.
8. `android.agp-mismatch`: Android Gradle Plugin version incompatible with Gradle.
9. `android.build-tools-missing`: Specified build-tools revision not installed.
10. `android.compile-sdk-mismatch`: `compileSdkVersion` lower than required by plugin.
11. `android.dependency-resolution-failure`: Maven repository resolution failure.
12. `android.ndk-mismatch`: Missing or incompatible Android NDK version.
13. `android.namespace-error`: AGP 8.0+ missing explicit `namespace` attribute.
14. `android.resource-linking-failed`: AAPT2 XML resource linking failure.
15. `android.missing-resource`: Missing drawable, layout, or string resource.
16. `android.plugin-compilation-error`: Android plugin Kotlin/Java compile error.
17. `android.signing-configuration`: Keystore credentials or alias missing.
18. `android.r8-proguard-failure`: R8 code shrinking keep-rules error.
19. `android.gradle-daemon-failure`: Gradle daemon crashed or heap OutOfMemoryError.
20. `android.gradle-failure`: General Gradle task execution failure.

### iOS Platform Rules (13 Rules)
21. `ios.xcode-build-failure`: General Xcode build task failure.
22. `ios.cocoapods-failure`: CocoaPods pod install or repository sync error.
23. `ios.signing-configuration`: Provisioning profile or signing team identity missing.
24. `ios.deployment-target-mismatch`: iOS deployment target lower than plugin requirement.
25. `ios.framework-missing`: Embedded framework or library binary not found.
26. `ios.module-not-found`: Objective-C / Swift module import failure.
27. `ios.arch-mismatch`: Architecture mismatch (arm64 vs x86_64 simulator).
28. `ios.bitcode-error`: Deprecated Xcode Bitcode compilation error.
29. `ios.header-not-found`: C/Objective-C header file missing.
30. `ios.metal-compiler-error`: Metal shader compilation failure.
31. `ios.swift-version-mismatch`: Swift language version mismatch.
32. `ios.clang-error`: Clang compiler frontend error.
33. `ios.plist-error`: Info.plist key/value schema error.

### General & Dart Build Rules (7 Rules)
34. `dart.pub-get-failed`: `pub get` or dependency constraint resolution failure.
35. `dart.sdk-mismatch`: Dart SDK version constraint mismatch in `pubspec.yaml`.
36. `dart.compilation-error`: Dart compiler / kernel snapshot compilation error.
37. `flutter.tool-exit`: Flutter CLI internal tool exit exception.
38. `flutter.doctor-issue`: Flutter doctor configuration warning.
39. `flutter.plugin-registration-failed`: GeneratedPluginRegistrant setup error.
40. `general.out-of-memory`: Environment RAM or swap exhaustion during build.

---

## Performance Diagnostics (7 Metrics & Threshold Checks)

Performance investigation evaluates frame timings against hardware refresh rate budgets (60Hz = 16.67ms, 120Hz = 8.33ms):

1. **p50 (Median) Build & Raster Duration**: Typical frame rendering latency.
2. **p90 & p95 Percentiles**: Tail latency indicators for occasional frame drops.
3. **p99 Worst-case Duration**: Peak latency snapshot during heavy workload.
4. **Slow Frame Percentage**: Percentage of frames exceeding frame budget.
5. **Jank Cause Classification**: Distinguishes UI Thread Build Jank vs GPU Thread Raster Jank.
6. **Hardware Budget Violation**: Identifies refresh rate target breaches.
7. **Trace Event Capping**: Safe handling of up to 50,000 DevTools trace events.
