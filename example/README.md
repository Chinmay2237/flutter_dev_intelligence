# Flutter Dev Intelligence Example

Demonstrates how to run `flutter_dev_intelligence` diagnostics both programmatically via Dart API and using the command-line interface.

---

## 1. Running Programmatic Diagnostics in Code

```dart
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() async {
  // 1. Static AST UI Analysis
  final uiResult = await UiAstAnalyzer.analyzeFile('lib/main.dart');
  print('UI Issues found: ${uiResult.issues.length}');

  // 2. Build Log Parsing
  final logIssues = BuildLogParser.parse('''
    FAILURE: Build failed with an exception.
    * What went wrong:
    Execution failed for task ':app:compileReleaseKotlin'.
    > Duplicate class com.example.Foo found in modules foo-1.0.jar and foo-2.0.jar
  ''');
  print('Build issues matched: ${logIssues.first.title}');

  // 3. Performance Trace Parsing
  final perfResult = PerformanceInputParser.parse([12.5, 18.2, 14.1, 22.0]);
  print('Slow frames count: ${perfResult.summary?.slowFrameCount}');
}
```

---

## 2. CLI Usage Examples

### Project Health Doctor

```bash
dart run flutter_dev_intelligence doctor
```

### Static AST UI Doctor

```bash
dart run flutter_dev_intelligence ui-doctor --project=. --severity=medium
```

### Build Log Doctor

```bash
dart run flutter_dev_intelligence build-doctor --log=build.log --format=markdown
```

### Performance Investigator

```bash
dart run flutter_dev_intelligence perf-investigator --trace=trace.json --refresh-rate=60
```
