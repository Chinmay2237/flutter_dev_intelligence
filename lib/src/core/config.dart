export 'project_config.dart';

/// Package version constant for flutter_dev_intelligence.
const String kPackageVersion = '1.0.4';

/// Immutable configuration for Flutter Dev Intelligence Diagnostic Engine.
class DevIntelligenceConfig {
  final bool enableBuildDoctor;
  final bool redactSecrets;
  final int maxLogSizeBytes;
  final bool enableDebugLogging;
  final bool enablePerformance;
  final bool enableUiDoctor;

  const DevIntelligenceConfig({
    this.enableBuildDoctor = true,
    this.redactSecrets = true,
    this.maxLogSizeBytes = 10485760, // 10MB default
    this.enableDebugLogging = false,
    this.enablePerformance = false,
    this.enableUiDoctor = false,
  });

  DevIntelligenceConfig copyWith({
    bool? enableBuildDoctor,
    bool? redactSecrets,
    int? maxLogSizeBytes,
    bool? enableDebugLogging,
    bool? enablePerformance,
    bool? enableUiDoctor,
  }) {
    return DevIntelligenceConfig(
      enableBuildDoctor: enableBuildDoctor ?? this.enableBuildDoctor,
      redactSecrets: redactSecrets ?? this.redactSecrets,
      maxLogSizeBytes: maxLogSizeBytes ?? this.maxLogSizeBytes,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
      enablePerformance: enablePerformance ?? this.enablePerformance,
      enableUiDoctor: enableUiDoctor ?? this.enableUiDoctor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableBuildDoctor': enableBuildDoctor,
      'redactSecrets': redactSecrets,
      'maxLogSizeBytes': maxLogSizeBytes,
      'enableDebugLogging': enableDebugLogging,
    };
  }

  factory DevIntelligenceConfig.fromJson(Map<String, dynamic> json) {
    return DevIntelligenceConfig(
      enableBuildDoctor: json['enableBuildDoctor'] as bool? ?? true,
      redactSecrets: json['redactSecrets'] as bool? ?? true,
      maxLogSizeBytes: json['maxLogSizeBytes'] as int? ?? 10485760,
      enableDebugLogging: json['enableDebugLogging'] as bool? ?? false,
    );
  }
}
