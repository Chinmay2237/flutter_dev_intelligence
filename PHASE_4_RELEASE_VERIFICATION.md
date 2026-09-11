# Phase 4 Release Verification

Verification audit for the Phase 4 developer preview. The final quality gate is summarized in `PHASE_4_RELEASE_VERIFICATION_REPORT.md`.

| Feature | Claimed status | Actual status | Source files | Tests | Manual evidence | Release risk |
| --- | --- | --- | --- | --- | --- | --- |
| Unified DoctorRunner | Complete | Implemented and connected to `doctor` | `lib/src/build_doctor/doctor_runner.dart`, `bin/flutter_dev.dart` | CLI process tests cover project, JSON, Markdown, log, invalid input | Re-run required | Medium |
| CLI executable | Complete | `flutter-dev` maps to `bin/flutter_dev.dart`; `dart run bin/flutter_dev.dart` works | `pubspec.yaml`, `bin/flutter_dev.dart` | Help/version and doctor process tests | Re-run required | Medium |
| Terminal reporting | Complete | Implemented from `DiagnosticReport` | `lib/src/build_doctor/reporting.dart`, `lib/src/core/models.dart` | Indirect CLI coverage; dedicated renderer tests absent | Re-run required | Medium |
| JSON reporting | Complete | Uses `JsonEncoder`; valid output path exists | `lib/src/build_doctor/reporting.dart` | CLI JSON parsing test | Re-run required | Low |
| Markdown reporting | Complete | Includes report headings, issues, limitations | `lib/src/core/models.dart` | CLI Markdown test | Re-run required | Low |
| Exit codes | Complete | 0 no issues, 1 diagnostics, 2 usage/path, 3 execution failure | `bin/flutter_dev.dart` | CLI invalid/log tests | Shell exit capture required | Medium |
| Lockfile analysis | Basic | Source counts and mismatch warnings; custom line parser | `lib/src/build_doctor/pubspec_lock_analyzer.dart` | Source/mismatch tests | Real lockfile cases required | High |
| Build Doctor | Expanded | Deterministic rules for common platform/dependency failures | `lib/src/build_doctor/log_parser.dart` | Positive rule tests and fixtures | Fixture/manual checks required | Medium |
| Frame timing | Implemented | Uses `SchedulerBinding` callback lifecycle and bounded samples | `lib/src/performance/performance_investigator.dart` | Empty-session lifecycle test only | Flutter callback integration limited | High |
| Example app | Added | Real public APIs, analyzed successfully previously | `example/lib/main.dart`, `example/pubspec.yaml` | No example test | Build/test verification required | Medium |
| AI | Optional | Boundary only; no provider/network/default credentials | `lib/src/ai/ai_provider.dart` | No provider tests needed | Documentation check required | Low |
| Privacy | Partial | Redactor exists; CLI does not persist raw logs automatically | `lib/src/core/secret_redactor.dart`, README | Basic redaction test | Secret search required | High |
| Public API | Available | Root exports intended modules including Flutter APIs | `lib/flutter_dev_intelligence.dart` | Package analysis | Publish dry-run required | Medium |
| Pub.dev readiness | Preview | Dry-run previously passed with dirty-worktree warning | `pubspec.yaml`, README, CHANGELOG | Package validation | Re-run required | High |
