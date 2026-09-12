import 'package:flutter/material.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize configuration
  const config = DevIntelligenceConfig();
  FlutterDevIntelligence.initialize(configuration: config);

  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  DiagnosticReport? _report;
  bool _loading = true;

  final String _sampleLog = '''
FAILURE: Build failed with an exception.

* What went wrong:
Could not resolve all dependencies for configuration ':app:debugCompileClasspath'.
> Could not find com.example.internal:core-sdk:2.1.0.

Task :app:compileDebugJavaWithJavac FAILED
BUILD FAILED in 3s
''';

  @override
  void initState() {
    super.initState();
    _analyzeLog();
  }

  Future<void> _analyzeLog() async {
    final report = await BuildDoctor.analyzeLog(
      _sampleLog,
      projectName: 'example-app',
    );
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final terminalOutput = report != null
        ? DiagnosticReportRenderer.renderTerminal(
            report,
            colorMode: ColorMode.never,
          )
        : 'Analyzing log...';

    return MaterialApp(
      title: 'Flutter Dev Intelligence Demo',
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Dev Intelligence Demo'),
          elevation: 2,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diagnostic Overview',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (_loading)
                const CircularProgressIndicator()
              else ...[
                Text('Total Findings: ${report?.findings.length ?? 0}'),
                Text(
                  'Primary Root Causes: ${report?.primaryFindings.length ?? 0}',
                ),
                Text(
                  'Cascading Errors: ${report?.cascadingFindings.length ?? 0}',
                ),
              ],
              const SizedBox(height: 16),
              const Text('Terminal Report Preview:'),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      terminalOutput,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
