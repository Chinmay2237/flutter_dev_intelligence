import 'dart:io';

/// Basic CLI helper for build doctor usage from terminal entrypoints.
class BuildDoctorCli {
  const BuildDoctorCli();

  static Future<int> run({
    String? projectPath,
    String? logPath,
    String outputFormat = 'terminal',
    bool verbose = false,
  }) async {
    if (logPath != null) {
      final file = File(logPath);
      if (!await file.exists()) {
        stderr.writeln('Log file not found: $logPath');
        return 2;
      }

      final content = await file.readAsString();
      final issues = content.trim().isEmpty ? const <String>[] : [content];

      if (outputFormat == 'json') {
        stdout.writeln('{"issues":${issues.length}}');
        return issues.isEmpty ? 0 : 1;
      }

      stdout.writeln('Build Doctor: scanned log file $logPath');
      stdout.writeln('Issue count: ${issues.length}');
      return issues.isEmpty ? 0 : 1;
    }

    if (projectPath != null) {
      final directory = Directory(projectPath);
      if (!await directory.exists()) {
        stderr.writeln('Project directory not found: $projectPath');
        return 2;
      }

      stdout.writeln('Build Doctor: project scan for $projectPath');
      return 0;
    }

    stdout.writeln('Build Doctor: no project or log was supplied.');
    return 2;
  }
}
