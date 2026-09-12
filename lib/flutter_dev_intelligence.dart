import 'src/core/config.dart';

export 'src/core/config.dart';
export 'src/core/models.dart';
export 'src/core/secret_redactor.dart';
export 'src/core/auto_fix_engine.dart';
export 'src/build_doctor/build_doctor.dart';
export 'src/build_doctor/build_doctor_cli.dart';
export 'src/build_doctor/build_doctor_rule.dart';
export 'src/build_doctor/build_log_normalizer.dart';
export 'src/build_doctor/log_classification.dart';
export 'src/build_doctor/doctor_runner.dart';
export 'src/build_doctor/log_parser.dart';
export 'src/build_doctor/project_scanner.dart';
export 'src/build_doctor/pubspec_analyzer.dart';
export 'src/build_doctor/pubspec_lock_analyzer.dart';
export 'src/build_doctor/reporting.dart';
export 'src/ai/ai_provider.dart';
export 'src/performance/performance_investigator.dart';
export 'src/performance/performance_input_parser.dart';
export 'src/ui_doctor/ui_doctor.dart';
export 'src/ui_doctor/ui_ast_analyzer.dart';
export 'src/ui_doctor/ui_ast_rule.dart';
export 'src/ui_doctor/ast_source_discoverer.dart';
export 'src/ui_doctor/ast_parser.dart';
export 'src/ui_doctor/widget_taxonomy.dart';
export 'src/ui_doctor/ast_analysis_context.dart';
export 'src/ui_doctor/ui_ast_rule_contract.dart';
export 'src/ui_doctor/rule_executor.dart';

/// Main package entrypoint for Flutter Dev Intelligence.
class FlutterDevIntelligence {
  const FlutterDevIntelligence._();

  static DevIntelligenceConfig initialize({
    DevIntelligenceConfig configuration = const DevIntelligenceConfig(),
  }) {
    return configuration;
  }
}
