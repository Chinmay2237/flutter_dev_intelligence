import 'src/core/config.dart';

export 'src/core/config.dart';
export 'src/core/models.dart';
export 'src/core/secret_redactor.dart';
export 'src/build_doctor/build_doctor.dart';
export 'src/build_doctor/build_doctor_engine.dart';
export 'src/build_doctor/build_doctor_cli.dart';
export 'src/build_doctor/doctor_runner.dart';
export 'src/build_doctor/input_loader.dart';
export 'src/build_doctor/log_normalizer.dart';
export 'src/build_doctor/log_parser.dart';
export 'src/build_doctor/diagnostic_rules.dart';
export 'src/build_doctor/rule_matcher.dart';
export 'src/build_doctor/root_cause_classifier.dart';
export 'src/build_doctor/pubspec_analyzer.dart';
export 'src/build_doctor/reporting.dart';

/// Main package entrypoint for Flutter Dev Intelligence.
class FlutterDevIntelligence {
  const FlutterDevIntelligence._();

  static DevIntelligenceConfig initialize({
    DevIntelligenceConfig configuration = const DevIntelligenceConfig(),
  }) {
    return configuration;
  }
}
