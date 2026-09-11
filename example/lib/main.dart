import 'package:flutter/material.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() {
  final performance = PerformanceInvestigator(sessionName: 'example');
  performance.startSession('example');
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final report = UiDoctor.inspectViewport(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      contentWidth: MediaQuery.sizeOf(context).width,
      contentHeight: MediaQuery.sizeOf(context).height,
    );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Dev Intelligence')),
        body: Center(
          child: Text('UI diagnostics: ${report.issues.length} issues'),
        ),
      ),
    );
  }
}
