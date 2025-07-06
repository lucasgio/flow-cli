import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/shared/models/device_model.dart';

class HotReloadUseCase {
  final ConfigService _configService = ConfigService.instance;

  Future<HotReloadSession?> startSession({
    required DeviceModel device,
    String? client,
    required bool verbose,
    required String logLevel,
  }) async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      // Build command arguments
      final args = ['run', '--device-id', device.id];

      // Add hot reload flag
      args.add('--hot');

      // Add flavor for multi-client
      if (client != null) {
        args.addAll(['--flavor', client]);
      }

      // Add verbose flag if requested
      if (verbose) {
        args.add('--verbose');
      }

      CliUtils.printInfo('Starting Flutter app with hot reload...');
      CliUtils.printInfo('Command: flutter ${args.join(' ')}');

      // Start the Flutter process
      final process = await Process.start(
        flutterBin,
        args,
        workingDirectory: projectPath,
        mode: ProcessStartMode.normal,
      );

      final session = HotReloadSession(
        process: process,
        device: device,
        client: client,
        startTime: DateTime.now(),
      );

      // Wait a bit to ensure the app starts
      await Future.delayed(Duration(seconds: 3));

      // Check if process is still running
      if (await _isProcessRunning(process)) {
        CliUtils.printSuccess('Hot reload session started successfully');
        return session;
      } else {
        CliUtils.printError('Failed to start Flutter app');
        return null;
      }
    } catch (e) {
      CliUtils.printError('Error starting hot reload session: $e');
      return null;
    }
  }

  Future<bool> _isProcessRunning(Process process) async {
    try {
      // Try to kill with signal 0 (just check if process exists)
      process.kill(ProcessSignal.sigusr1);
      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<LogEntry> getLogStream(HotReloadSession session) {
    final controller = StreamController<LogEntry>();

    // Listen to stdout
    session.process.stdout
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        final logEntry = _parseLogLine(line, 'stdout');
        controller.add(logEntry);
      }
    });

    // Listen to stderr
    session.process.stderr
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        final logEntry = _parseLogLine(line, 'stderr');
        controller.add(logEntry);
      }
    });

    // Handle process exit
    session.process.exitCode.then((exitCode) {
      controller.add(LogEntry(
        level: 'info',
        message: 'Flutter process exited with code: $exitCode',
        timestamp: DateTime.now(),
        source: 'system',
      ));
      controller.close();
    });

    return controller.stream;
  }

  LogEntry _parseLogLine(String line, String source) {
    final timestamp = DateTime.now();

    // Parse Flutter log levels
    String level = 'info';
    String message = line;

    if (line.contains('[ERROR]') ||
        line.contains('ERROR:') ||
        line.contains('Exception:')) {
      level = 'error';
    } else if (line.contains('[WARNING]') ||
        line.contains('WARNING:') ||
        line.contains('Warning:')) {
      level = 'warning';
    } else if (line.contains('[DEBUG]') || line.contains('DEBUG:')) {
      level = 'debug';
    } else if (line.contains('[INFO]') || line.contains('INFO:')) {
      level = 'info';
    }

    // Clean up common Flutter prefixes
    message = message
        .replaceAll(
            RegExp(r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] '), '')
        .replaceAll(RegExp(r'^(DEBUG|INFO|WARNING|ERROR):\s*'), '')
        .replaceAll(RegExp(r'^\[.+?\]\s*'), '')
        .trim();

    return LogEntry(
      level: level,
      message: message,
      timestamp: timestamp,
      source: source,
      rawLine: line,
    );
  }

  Future<bool> performHotReload(HotReloadSession session) async {
    try {
      // Send 'r' command to Flutter process for hot reload
      session.process.stdin.writeln('r');
      await session.process.stdin.flush();

      // Wait a bit for the reload to process
      await Future.delayed(Duration(milliseconds: 500));

      return true;
    } catch (e) {
      CliUtils.printError('Hot reload error: $e');
      return false;
    }
  }

  Future<bool> performHotRestart(HotReloadSession session) async {
    try {
      // Send 'R' command to Flutter process for hot restart
      session.process.stdin.writeln('R');
      await session.process.stdin.flush();

      // Wait a bit for the restart to process
      await Future.delayed(Duration(seconds: 2));

      return true;
    } catch (e) {
      CliUtils.printError('Hot restart error: $e');
      return false;
    }
  }

  Future<String?> captureScreenshot(DeviceModel device) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final screenshotDir = Directory('screenshots');

      if (!await screenshotDir.exists()) {
        await screenshotDir.create();
      }

      final screenshotPath = path.join(
          screenshotDir.path, 'screenshot_${device.platform}_$timestamp.png');

      if (device.platform == 'android') {
        return await _captureAndroidScreenshot(device, screenshotPath);
      } else if (device.platform == 'ios') {
        return await _captureIOSScreenshot(device, screenshotPath);
      }

      return null;
    } catch (e) {
      CliUtils.printError('Screenshot capture error: $e');
      return null;
    }
  }

  Future<String?> _captureAndroidScreenshot(
      DeviceModel device, String outputPath) async {
    try {
      // Use ADB to capture screenshot
      final result = await Process.run(
        'adb',
        ['-s', device.id, 'exec-out', 'screencap', '-p'],
      );

      if (result.exitCode == 0) {
        final file = File(outputPath);
        await file.writeAsBytes(result.stdout);
        return outputPath;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _captureIOSScreenshot(
      DeviceModel device, String outputPath) async {
    try {
      // Use xcrun simctl for iOS simulator screenshots
      final result = await Process.run(
        'xcrun',
        ['simctl', 'io', device.id, 'screenshot', outputPath],
      );

      if (result.exitCode == 0) {
        return outputPath;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getPerformanceMetrics(
      HotReloadSession session) async {
    try {
      // This would integrate with Flutter's performance monitoring
      // For now, return basic metrics
      return {
        'uptime': DateTime.now().difference(session.startTime).inMilliseconds,
        'device': session.device.name,
        'platform': session.device.platform,
        'reloads': session.reloadCount,
        'restarts': session.restartCount,
      };
    } catch (e) {
      return {};
    }
  }

  Future<void> enablePerformanceOverlay(HotReloadSession session) async {
    try {
      // Send command to enable performance overlay
      session.process.stdin.writeln('P');
      await session.process.stdin.flush();
    } catch (e) {
      CliUtils.printError('Failed to enable performance overlay: $e');
    }
  }

  Future<void> toggleDebugPaint(HotReloadSession session) async {
    try {
      // Send command to toggle debug paint
      session.process.stdin.writeln('p');
      await session.process.stdin.flush();
    } catch (e) {
      CliUtils.printError('Failed to toggle debug paint: $e');
    }
  }

  Future<void> toggleWidgetInspector(HotReloadSession session) async {
    try {
      // Send command to toggle widget inspector
      session.process.stdin.writeln('w');
      await session.process.stdin.flush();
    } catch (e) {
      CliUtils.printError('Failed to toggle widget inspector: $e');
    }
  }

  Future<List<String>> getConnectedDevices() async {
    try {
      final flutterPath = _configService.flutterPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      final result = await Process.run(
        flutterBin,
        ['devices', '--machine'],
      );

      if (result.exitCode == 0) {
        final devices = jsonDecode(result.stdout) as List;
        return devices
            .map((device) => device['id'] as String)
            .where((id) => id.isNotEmpty)
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}

class HotReloadSession {
  final Process process;
  final DeviceModel device;
  final String? client;
  final DateTime startTime;

  int reloadCount = 0;
  int restartCount = 0;

  HotReloadSession({
    required this.process,
    required this.device,
    required this.client,
    required this.startTime,
  });

  Future<void> stop() async {
    try {
      // Send quit command
      process.stdin.writeln('q');
      await process.stdin.flush();

      // Wait a bit for graceful shutdown
      await Future.delayed(Duration(seconds: 1));

      // Force kill if still running
      if (!process.kill()) {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (e) {
      // Force kill if all else fails
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }

  Future<int> waitForExit() async {
    return await process.exitCode;
  }

  bool get isRunning {
    try {
      process.kill(ProcessSignal.sigusr1);
      return true;
    } catch (e) {
      return false;
    }
  }
}

class LogEntry {
  final String level;
  final String message;
  final DateTime timestamp;
  final String source;
  final String? rawLine;

  LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    required this.source,
    this.rawLine,
  });

  @override
  String toString() {
    return '[$level] $message';
  }
}
