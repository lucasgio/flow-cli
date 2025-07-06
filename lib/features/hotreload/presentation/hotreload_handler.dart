import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:interact/interact.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/localization_service.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/features/hotreload/domain/hotreload_usecase.dart';
import 'package:flow_cli/features/device/domain/device_usecase.dart';
import 'package:flow_cli/shared/models/device_model.dart';

class HotReloadHandler {
  final HotReloadUseCase _hotReloadUseCase = HotReloadUseCase();
  final DeviceUseCase _deviceUseCase = DeviceUseCase();
  final LocalizationService _localization = LocalizationService.instance;
  final ConfigService _configService = ConfigService.instance;

  Future<void> handle(List<String> args) async {
    final parser = ArgParser()
      ..addOption('device', help: 'Target device ID')
      ..addOption('client', help: 'Client name for multi-client apps')
      ..addFlag('verbose', abbr: 'v', help: 'Verbose logging', negatable: false)
      ..addFlag('quiet', abbr: 'q', help: 'Minimal output', negatable: false)
      ..addOption('log-level',
          help: 'Log level filter (all, debug, info, warning, error)',
          defaultsTo: 'all')
      ..addFlag('no-sound',
          help: 'Disable sound notifications', negatable: false)
      ..addFlag('help',
          abbr: 'h', help: 'Show help for hotreload command', negatable: false);

    try {
      final results = parser.parse(args);

      if (results['help']) {
        _showHelp(parser);
        return;
      }

      if (!_configService.isConfigured) {
        CliUtils.printError(
            'Flow CLI is not configured. Please run: flow setup');
        exit(1);
      }

      final deviceId = results['device'] as String?;
      final client = results['client'] as String?;
      final verbose = results['verbose'] as bool;
      final quiet = results['quiet'] as bool;
      final logLevel = results['log-level'] as String;
      final noSound = results['no-sound'] as bool;

      // Handle multi-client requirement
      if (_configService.multiClient && client == null) {
        CliUtils.printError('Multi-client mode requires --client parameter');
        CliUtils.printInfo(
            'Available clients: ${_configService.clients.join(', ')}');
        exit(1);
      }

      // Get target device
      final targetDevice = await _selectTargetDevice(deviceId);
      if (targetDevice == null) {
        CliUtils.printError('No suitable device found');
        exit(1);
      }

      CliUtils.printInfo('Starting hot reload session...');
      CliUtils.printInfo(
          'Target device: ${targetDevice.name} (${targetDevice.platform})');
      if (client != null) CliUtils.printInfo('Client: $client');

      // Start hot reload session
      await _startHotReloadSession(
        device: targetDevice,
        client: client,
        verbose: verbose,
        quiet: quiet,
        logLevel: logLevel,
        soundEnabled: !noSound,
      );
    } catch (e) {
      CliUtils.printError('Hot reload failed: $e');
      exit(1);
    }
  }

  Future<DeviceModel?> _selectTargetDevice(String? deviceId) async {
    final devices = await _deviceUseCase.getDevices();

    if (devices.isEmpty) {
      CliUtils.printWarning('No devices found');
      return null;
    }

    // Filter online devices
    final onlineDevices = devices.where((d) => d.isOnline).toList();
    if (onlineDevices.isEmpty) {
      CliUtils.printWarning('No online devices found');
      return null;
    }

    // If device ID specified, find it
    if (deviceId != null) {
      final device = onlineDevices.where((d) => d.id == deviceId).isEmpty
          ? null
          : onlineDevices.where((d) => d.id == deviceId).first;
      if (device == null) {
        CliUtils.printError('Device with ID "$deviceId" not found or offline');
      }
      return device;
    }

    // If only one device, use it
    if (onlineDevices.length == 1) {
      return onlineDevices.first;
    }

    // Let user select device
    final deviceNames = onlineDevices
        .map((d) => '${d.name} (${d.platform}) - ${d.id}')
        .toList();
    final selectionIndex = Select(
      prompt: 'Select device for hot reload:',
      options: deviceNames,
    ).interact();

    return onlineDevices[selectionIndex];
  }

  Future<void> _startHotReloadSession({
    required DeviceModel device,
    String? client,
    required bool verbose,
    required bool quiet,
    required String logLevel,
    required bool soundEnabled,
  }) async {
    try {
      // Start the Flutter app with hot reload
      final hotReloadSession = await _hotReloadUseCase.startSession(
        device: device,
        client: client,
        verbose: verbose,
        logLevel: logLevel,
      );

      if (hotReloadSession == null) {
        CliUtils.printError('Failed to start hot reload session');
        return;
      }

      if (!quiet) {
        _printHotReloadInstructions();
      }

      // Set up keyboard input handling
      stdin.echoMode = false;
      stdin.lineMode = false;

      // Start log streaming
      late StreamSubscription<LogEntry> logSubscription;
      late StreamSubscription<List<int>> keyboardSubscription;

      logSubscription =
          _hotReloadUseCase.getLogStream(hotReloadSession).listen((logEntry) {
        _printLogEntry(logEntry, logLevel, verbose);
      });

      // Handle keyboard input
      keyboardSubscription = stdin.listen((data) async {
        final key = String.fromCharCodes(data).toLowerCase();

        switch (key) {
          case 'r':
            await _performHotReload(hotReloadSession, soundEnabled);
            break;
          case 'R':
            await _performHotRestart(hotReloadSession, soundEnabled);
            break;
          case 'h':
            _printHotReloadInstructions();
            break;
          case 'c':
            _clearConsole();
            break;
          case 'l':
            await _toggleLogLevel();
            break;
          case 'v':
            verbose = !verbose;
            CliUtils.printInfo('Verbose mode: ${verbose ? 'ON' : 'OFF'}');
            break;
          case 'q':
            CliUtils.printInfo('Stopping hot reload session...');
            await hotReloadSession.stop();
            await logSubscription.cancel();
            await keyboardSubscription.cancel();
            stdin.echoMode = true;
            stdin.lineMode = true;
            CliUtils.printSuccess('Hot reload session stopped');
            return;
          case 's':
            await _captureScreenshot(device);
            break;
          case 'd':
            await _showDeviceInfo(device);
            break;
        }
      });

      // Wait for session to end
      await hotReloadSession.waitForExit();

      // Cleanup
      await logSubscription.cancel();
      await keyboardSubscription.cancel();
      stdin.echoMode = true;
      stdin.lineMode = true;

      CliUtils.printInfo('Hot reload session ended');
    } catch (e) {
      CliUtils.printError('Hot reload session error: $e');
      stdin.echoMode = true;
      stdin.lineMode = true;
    }
  }

  void _printHotReloadInstructions() {
    print('\n${CliUtils.formatTitle('Hot Reload Controls')}');
    CliUtils.printSeparator();
    print('${CliUtils.formatSubtitle('Commands:')}');
    print('  r  - Hot reload (⚡)');
    print('  R  - Hot restart (🔄)');
    print('  h  - Show this help');
    print('  c  - Clear console');
    print('  l  - Toggle log level');
    print('  v  - Toggle verbose mode');
    print('  s  - Capture screenshot');
    print('  d  - Show device info');
    print('  q  - Quit hot reload session');
    CliUtils.printSeparator();
    print('');
  }

  Future<void> _performHotReload(
      HotReloadSession session, bool soundEnabled) async {
    CliUtils.clearLine();
    stdout.write('⚡ Hot reloading...');

    final stopwatch = Stopwatch()..start();
    final success = await _hotReloadUseCase.performHotReload(session);
    stopwatch.stop();

    CliUtils.clearLine();

    if (success) {
      CliUtils.printSuccess(
          '⚡ Hot reload completed in ${stopwatch.elapsedMilliseconds}ms');
      if (soundEnabled) _playSuccessSound();
    } else {
      CliUtils.printError('❌ Hot reload failed');
      if (soundEnabled) _playErrorSound();
    }
  }

  Future<void> _performHotRestart(
      HotReloadSession session, bool soundEnabled) async {
    CliUtils.clearLine();
    stdout.write('🔄 Hot restarting...');

    final stopwatch = Stopwatch()..start();
    final success = await _hotReloadUseCase.performHotRestart(session);
    stopwatch.stop();

    CliUtils.clearLine();

    if (success) {
      CliUtils.printSuccess(
          '🔄 Hot restart completed in ${stopwatch.elapsedMilliseconds}ms');
      if (soundEnabled) _playSuccessSound();
    } else {
      CliUtils.printError('❌ Hot restart failed');
      if (soundEnabled) _playErrorSound();
    }
  }

  void _printLogEntry(LogEntry logEntry, String logLevel, bool verbose) {
    // Filter logs based on level
    if (!_shouldShowLogLevel(logEntry.level, logLevel)) {
      return;
    }

    final timestamp = verbose
        ? '[${logEntry.timestamp.toIso8601String().substring(11, 23)}] '
        : '';

    final levelIcon = _getLogLevelIcon(logEntry.level);
    final levelColor = _getLogLevelColor(logEntry.level);

    final formattedMessage = '$timestamp$levelIcon ${logEntry.message}';

    switch (levelColor) {
      case 'red':
        print('\x1b[31m$formattedMessage\x1b[0m');
        break;
      case 'yellow':
        print('\x1b[33m$formattedMessage\x1b[0m');
        break;
      case 'blue':
        print('\x1b[34m$formattedMessage\x1b[0m');
        break;
      case 'gray':
        print('\x1b[90m$formattedMessage\x1b[0m');
        break;
      default:
        print(formattedMessage);
    }
  }

  bool _shouldShowLogLevel(String entryLevel, String filterLevel) {
    const levels = ['debug', 'info', 'warning', 'error'];
    if (filterLevel == 'all') return true;

    final filterIndex = levels.indexOf(filterLevel);
    final entryIndex = levels.indexOf(entryLevel);

    return entryIndex >= filterIndex;
  }

  String _getLogLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return '❌';
      case 'warning':
        return '⚠️';
      case 'info':
        return 'ℹ️';
      case 'debug':
        return '🐛';
      default:
        return '📝';
    }
  }

  String _getLogLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return 'red';
      case 'warning':
        return 'yellow';
      case 'info':
        return 'blue';
      case 'debug':
        return 'gray';
      default:
        return 'white';
    }
  }

  void _clearConsole() {
    if (Platform.isWindows) {
      Process.runSync('cls', [], runInShell: true);
    } else {
      Process.runSync('clear', []);
    }
    _printHotReloadInstructions();
  }

  Future<void> _toggleLogLevel() async {
    const levels = ['all', 'debug', 'info', 'warning', 'error'];
    final currentIndex = levels.indexOf('all'); // Default
    final nextIndex = (currentIndex + 1) % levels.length;
    final newLevel = levels[nextIndex];

    CliUtils.printInfo('Log level changed to: $newLevel');
  }

  Future<void> _captureScreenshot(DeviceModel device) async {
    try {
      CliUtils.printInfo('📸 Capturing screenshot...');
      final screenshotPath = await _hotReloadUseCase.captureScreenshot(device);

      if (screenshotPath != null) {
        CliUtils.printSuccess('Screenshot saved: $screenshotPath');
      } else {
        CliUtils.printError('Failed to capture screenshot');
      }
    } catch (e) {
      CliUtils.printError('Screenshot error: $e');
    }
  }

  Future<void> _showDeviceInfo(DeviceModel device) async {
    print('\n${CliUtils.formatTitle('Device Information')}');
    CliUtils.printSeparator();
    print('Name: ${device.name}');
    print('Platform: ${device.platform}');
    print('ID: ${device.id}');
    print('Type: ${device.isPhysical ? 'Physical Device' : 'Emulator'}');
    print('Status: ${device.isOnline ? 'Online' : 'Offline'}');
    if (device.version != null) print('Version: ${device.version}');
    if (device.architecture != null)
      print('Architecture: ${device.architecture}');
    CliUtils.printSeparator();
    print('');
  }

  void _playSuccessSound() {
    // Simple terminal bell for success
    stdout.write('\x07');
  }

  void _playErrorSound() {
    // Double bell for errors
    stdout.write('\x07');
    Future.delayed(Duration(milliseconds: 100), () => stdout.write('\x07'));
  }

  void _showHelp(ArgParser parser) {
    print('''
${CliUtils.formatTitle('Flow CLI Hot Reload')}

Start hot reload session with real-time logging

${CliUtils.formatSubtitle('Usage:')}
  flow hotreload [options]

${CliUtils.formatSubtitle('Options:')}
${parser.usage}

${CliUtils.formatSubtitle('Interactive Commands:')}
  r  - Hot reload (⚡)
  R  - Hot restart (🔄)
  h  - Show help
  c  - Clear console
  l  - Toggle log level
  v  - Toggle verbose mode
  s  - Capture screenshot
  d  - Show device info
  q  - Quit session

${CliUtils.formatSubtitle('Examples:')}
  flow hotreload
  flow hotreload --device emulator-5554
  flow hotreload --client client1 --verbose
  flow hotreload --log-level warning --no-sound
''');
  }
}
