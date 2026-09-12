export 'project_config.dart';

/// Package version constant for flutter_dev_intelligence.
const String kPackageVersion = '1.0.2';

/// Immutable runtime configuration for Flutter Dev Intelligence.
class DevIntelligenceConfig {
  /// Enables runtime performance collection.
  final bool enablePerformance;

  /// Enables UI doctor diagnostics and metadata collection.
  final bool enableUiDoctor;

  /// Enables build doctor checks within an app runtime session.
  final bool enableBuildDoctor;

  /// Enables debug logging for diagnostics collection.
  final bool enableDebugLogging;

  /// Tracks network timing when supported by the host app.
  final bool enableNetworkTracking;

  /// Tracks memory indicators when supported by the host app.
  final bool enableMemoryTracking;

  /// Enables route timing for navigation events.
  final bool enableRouteTracking;

  /// Enables timeline-based custom events.
  final bool enableTimelineEvents;

  /// Restricts instrumentation to debug builds only.
  final bool debugOnly;

  /// Sampling rate used for runtime instrumentation.
  final int sampleRate;

  /// Maximum number of recorded tracing events.
  final int maxEvents;

  const DevIntelligenceConfig({
    this.enablePerformance = true,
    this.enableUiDoctor = true,
    this.enableBuildDoctor = false,
    this.enableDebugLogging = false,
    this.enableNetworkTracking = false,
    this.enableMemoryTracking = false,
    this.enableRouteTracking = true,
    this.enableTimelineEvents = true,
    this.debugOnly = true,
    this.sampleRate = 1,
    this.maxEvents = 10000,
  }) : assert(sampleRate > 0, 'sampleRate must be greater than zero'),
       assert(maxEvents > 0, 'maxEvents must be greater than zero');

  /// Returns a copy with selected fields replaced.
  DevIntelligenceConfig copyWith({
    bool? enablePerformance,
    bool? enableUiDoctor,
    bool? enableBuildDoctor,
    bool? enableDebugLogging,
    bool? enableNetworkTracking,
    bool? enableMemoryTracking,
    bool? enableRouteTracking,
    bool? enableTimelineEvents,
    bool? debugOnly,
    int? sampleRate,
    int? maxEvents,
  }) {
    return DevIntelligenceConfig(
      enablePerformance: enablePerformance ?? this.enablePerformance,
      enableUiDoctor: enableUiDoctor ?? this.enableUiDoctor,
      enableBuildDoctor: enableBuildDoctor ?? this.enableBuildDoctor,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
      enableNetworkTracking:
          enableNetworkTracking ?? this.enableNetworkTracking,
      enableMemoryTracking: enableMemoryTracking ?? this.enableMemoryTracking,
      enableRouteTracking: enableRouteTracking ?? this.enableRouteTracking,
      enableTimelineEvents: enableTimelineEvents ?? this.enableTimelineEvents,
      debugOnly: debugOnly ?? this.debugOnly,
      sampleRate: sampleRate ?? this.sampleRate,
      maxEvents: maxEvents ?? this.maxEvents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enablePerformance': enablePerformance,
      'enableUiDoctor': enableUiDoctor,
      'enableBuildDoctor': enableBuildDoctor,
      'enableDebugLogging': enableDebugLogging,
      'enableNetworkTracking': enableNetworkTracking,
      'enableMemoryTracking': enableMemoryTracking,
      'enableRouteTracking': enableRouteTracking,
      'enableTimelineEvents': enableTimelineEvents,
      'debugOnly': debugOnly,
      'sampleRate': sampleRate,
      'maxEvents': maxEvents,
    };
  }

  factory DevIntelligenceConfig.fromJson(Map<String, dynamic> json) {
    return DevIntelligenceConfig(
      enablePerformance: json['enablePerformance'] as bool? ?? true,
      enableUiDoctor: json['enableUiDoctor'] as bool? ?? true,
      enableBuildDoctor: json['enableBuildDoctor'] as bool? ?? false,
      enableDebugLogging: json['enableDebugLogging'] as bool? ?? false,
      enableNetworkTracking: json['enableNetworkTracking'] as bool? ?? false,
      enableMemoryTracking: json['enableMemoryTracking'] as bool? ?? false,
      enableRouteTracking: json['enableRouteTracking'] as bool? ?? true,
      enableTimelineEvents: json['enableTimelineEvents'] as bool? ?? true,
      debugOnly: json['debugOnly'] as bool? ?? true,
      sampleRate: json['sampleRate'] as int? ?? 1,
      maxEvents: json['maxEvents'] as int? ?? 10000,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DevIntelligenceConfig &&
        other.enablePerformance == enablePerformance &&
        other.enableUiDoctor == enableUiDoctor &&
        other.enableBuildDoctor == enableBuildDoctor &&
        other.enableDebugLogging == enableDebugLogging &&
        other.enableNetworkTracking == enableNetworkTracking &&
        other.enableMemoryTracking == enableMemoryTracking &&
        other.enableRouteTracking == enableRouteTracking &&
        other.enableTimelineEvents == enableTimelineEvents &&
        other.debugOnly == debugOnly &&
        other.sampleRate == sampleRate &&
        other.maxEvents == maxEvents;
  }

  @override
  int get hashCode => Object.hash(
    enablePerformance,
    enableUiDoctor,
    enableBuildDoctor,
    enableDebugLogging,
    enableNetworkTracking,
    enableMemoryTracking,
    enableRouteTracking,
    enableTimelineEvents,
    debugOnly,
    sampleRate,
    maxEvents,
  );
}
