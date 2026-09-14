export 'project_config.dart';

/// Package version constant for flutter_dev_intelligence.
const String kPackageVersion = '1.2.1';

/// Immutable configuration for Flutter Dev Intelligence Diagnostic Engine.
class DevIntelligenceConfig {
  /// Whether to enable Build Doctor build log analysis features.
  final bool enableBuildDoctor;

  /// Whether to redact secrets from diagnostic outputs.
  final bool redactSecrets;

  /// Maximum log size in bytes to process.
  final int maxLogSizeBytes;

  /// Whether to enable verbose internal debug logging.
  final bool enableDebugLogging;

  /// Whether to enable performance diagnostic checks.
  final bool enablePerformance;

  /// Whether to enable UI Doctor static code analysis.
  final bool enableUiDoctor;

  /// Creates a new [DevIntelligenceConfig] instance with specified options.
  const DevIntelligenceConfig({
    this.enableBuildDoctor = true,
    this.redactSecrets = true,
    this.maxLogSizeBytes = 10485760, // 10MB default
    this.enableDebugLogging = false,
    this.enablePerformance = false,
    this.enableUiDoctor = true,
  });

  /// Creates a copy of this configuration with updated fields.
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

  /// Converts this configuration instance into a JSON-encodable map.
  Map<String, dynamic> toJson() {
    return {
      'enableBuildDoctor': enableBuildDoctor,
      'redactSecrets': redactSecrets,
      'maxLogSizeBytes': maxLogSizeBytes,
      'enableDebugLogging': enableDebugLogging,
    };
  }

  /// Restores a [DevIntelligenceConfig] instance from a JSON map.
  factory DevIntelligenceConfig.fromJson(Map<String, dynamic> json) {
    return DevIntelligenceConfig(
      enableBuildDoctor: json['enableBuildDoctor'] as bool? ?? true,
      redactSecrets: json['redactSecrets'] as bool? ?? true,
      maxLogSizeBytes: json['maxLogSizeBytes'] as int? ?? 10485760,
      enableDebugLogging: json['enableDebugLogging'] as bool? ?? false,
    );
  }
}
