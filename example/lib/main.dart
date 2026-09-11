import 'package:flutter/material.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize configuration with local-first defaults
  const config = DevIntelligenceConfig();
  FlutterDevIntelligence.initialize(configuration: config);

  // Performance tracking session
  final performance = PerformanceInvestigator(sessionName: 'example-session');
  performance.startSession('example-session');
  performance.startTrace('app_initialization');
  performance.endTrace('app_initialization', durationMs: 14.2);

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inspect current layout constraints
    final report = UiDoctor.inspectViewport(
      width: 360,
      height: 640,
      contentWidth: 360,
      contentHeight: 640,
    );

    final terminalOutput = DiagnosticReportRenderer.renderTerminal(report);

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
              Text('Detected Issues: ${report.issues.length}'),
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
