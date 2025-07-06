import 'dart:io';
import 'package:args/args.dart';
import 'package:interact/interact.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/core/utils/logger.dart';
import 'package:flow_cli/shared/services/localization_service.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/features/device/domain/device_usecase.dart';
import 'package:flow_cli/features/hotreload/presentation/hotreload_handler.dart';
import 'package:flow_cli/shared/models/device_model.dart';

class DeviceHandler {
  final DeviceUseCase _deviceUseCase = DeviceUseCase();
  final HotReloadHandler _hotReloadHandler = HotReloadHandler();
  final LocalizationService _localization = LocalizationService.instance;
  final ConfigService _configService = ConfigService.instance;
  final _logger = AppLogger.instance;

  Future<void> handle(List<String> args) async {
    final parser = ArgParser()
      ..addOption('platform', help: 'Filter by platform (android/ios)')
      ..addOption('client', help: 'Client name for multi-client deployment')
      ..addFlag('physical',
          help: 'Show only physical devices', negatable: false)
      ..addFlag('emulator', help: 'Show only emulators', negatable: false)
      ..addFlag('watch', help: 'Watch for device changes', negatable: false)
      ..addFlag('help',
          abbr: 'h', help: 'Show help for device command', negatable: false);

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

      final command = results.rest.isNotEmpty ? results.rest[0] : 'list';
      final platform = results['platform'] as String?;
      final client = results['client'] as String?;

      switch (command) {
        case 'list':
          await _listDevices(
              platform, results['physical'], results['emulator']);
          break;
        case 'run':
          await _runOnDevice(platform, client, results.rest.skip(1).toList());
          break;
        case 'logs':
          await _showLogs(platform, results.rest.skip(1).toList());
          break;
        case 'install':
          await _installApp(platform, client, results.rest.skip(1).toList());
          break;
        case 'uninstall':
          await _uninstallApp(platform, client, results.rest.skip(1).toList());
          break;
        case 'hotreload':
          await _startHotReload(
              platform, client, results.rest.skip(1).toList());
          break;
        default:
          CliUtils.printError('Unknown device command: $command');
          _showHelp(parser);
          exit(1);
      }
    } catch (e) {
      CliUtils.printError('Device command failed: $e');
      exit(1);
    }
  }

  Future<void> _listDevices(
      String? platform, bool physicalOnly, bool emulatorOnly) async {
    CliUtils.printInfo(_localization.translate('device.listing'));

    final devices = await _deviceUseCase.getDevices(platform: platform);

    if (devices.isEmpty) {
      CliUtils.printWarning(_localization.translate('device.none_found'));
      return;
    }

    // Filter devices based on type
    List<DeviceModel> filteredDevices = devices;
    if (physicalOnly) {
      filteredDevices = devices.where((d) => d.isPhysical).toList();
    } else if (emulatorOnly) {
      filteredDevices = devices.where((d) => !d.isPhysical).toList();
    }

    if (filteredDevices.isEmpty) {
      CliUtils.printWarning('No devices found matching the criteria');
      return;
    }

    CliUtils.printSeparator();
    _logger.info(CliUtils.formatTitle('Available Devices'));
    CliUtils.printSeparator();

    for (final device in filteredDevices) {
      _printDevice(device);
    }
  }

  Future<void> _runOnDevice(
      String? platform, String? client, List<String> args) async {
    final devices = await _deviceUseCase.getDevices(platform: platform);

    if (devices.isEmpty) {
      CliUtils.printWarning(_localization.translate('device.none_found'));
      return;
    }

    DeviceModel selectedDevice;

    if (devices.length == 1) {
      selectedDevice = devices.first;
    } else {
      // Let user select device
      final deviceNames =
          devices.map((d) => '${d.name} (${d.platform})').toList();
      final selectionIndex = Select(
        prompt: 'Select device:',
        options: deviceNames,
      ).interact();

      selectedDevice = devices[selectionIndex];
    }

    CliUtils.printInfo('Running on device: ${selectedDevice.name}');

    // Handle multi-client
    if (_configService.multiClient && client == null) {
      CliUtils.printError('Multi-client mode requires --client parameter');
      CliUtils.printInfo(
          'Available clients: ${_configService.clients.join(', ')}');
      exit(1);
    }

    final success = await _deviceUseCase.runOnDevice(
      selectedDevice,
      client: client,
      additionalArgs: args,
    );

    if (success) {
      CliUtils.printSuccess(
          _localization.translate('device.deployment_success'));
    } else {
      CliUtils.printError('Failed to run on device');
      exit(1);
    }
  }

  Future<void> _showLogs(String? platform, List<String> args) async {
    final devices = await _deviceUseCase.getDevices(platform: platform);

    if (devices.isEmpty) {
      CliUtils.printWarning(_localization.translate('device.none_found'));
      return;
    }

    DeviceModel selectedDevice;

    if (devices.length == 1) {
      selectedDevice = devices.first;
    } else {
      final deviceNames =
          devices.map((d) => '${d.name} (${d.platform})').toList();
      final selectionIndex = Select(
        prompt: 'Select device for logs:',
        options: deviceNames,
      ).interact();

      selectedDevice = devices[selectionIndex];
    }

    CliUtils.printInfo('Showing logs for: ${selectedDevice.name}');
    await _deviceUseCase.showLogs(selectedDevice);
  }

  Future<void> _installApp(
      String? platform, String? client, List<String> args) async {
    final devices = await _deviceUseCase.getDevices(platform: platform);

    if (devices.isEmpty) {
      CliUtils.printWarning(_localization.translate('device.none_found'));
      return;
    }

    DeviceModel selectedDevice;

    if (devices.length == 1) {
      selectedDevice = devices.first;
    } else {
      final deviceNames =
          devices.map((d) => '${d.name} (${d.platform})').toList();
      final selectionIndex = Select(
        prompt: 'Select device for installation:',
        options: deviceNames,
      ).interact();

      selectedDevice = devices[selectionIndex];
    }

    final success =
        await _deviceUseCase.installApp(selectedDevice, client: client);

    if (success) {
      CliUtils.printSuccess('App installed successfully');
    } else {
      CliUtils.printError('Failed to install app');
      exit(1);
    }
  }

  Future<void> _uninstallApp(
      String? platform, String? client, List<String> args) async {
    final devices = await _deviceUseCase.getDevices(platform: platform);

    if (devices.isEmpty) {
      CliUtils.printWarning(_localization.translate('device.none_found'));
      return;
    }

    DeviceModel selectedDevice;

    if (devices.length == 1) {
      selectedDevice = devices.first;
    } else {
      final deviceNames =
          devices.map((d) => '${d.name} (${d.platform})').toList();
      final selectionIndex = Select(
        prompt: 'Select device for uninstallation:',
        options: deviceNames,
      ).interact();

      selectedDevice = devices[selectionIndex];
    }

    final success =
        await _deviceUseCase.uninstallApp(selectedDevice, client: client);

    if (success) {
      CliUtils.printSuccess('App uninstalled successfully');
    } else {
      CliUtils.printError('Failed to uninstall app');
      exit(1);
    }
  }

  Future<void> _startHotReload(
      String? platform, String? client, List<String> args) async {
    // Build arguments for hotreload command
    final hotReloadArgs = <String>[];

    if (platform != null) {
      // Filter devices by platform when selecting
      final devices = await _deviceUseCase.getDevices(platform: platform);
      if (devices.isNotEmpty) {
        hotReloadArgs.addAll(['--device', devices.first.id]);
      }
    }

    if (client != null) {
      hotReloadArgs.addAll(['--client', client]);
    }

    // Add any additional arguments passed
    hotReloadArgs.addAll(args);

    // Delegate to HotReloadHandler
    await _hotReloadHandler.handle(hotReloadArgs);
  }

  void _printDevice(DeviceModel device) {
    final statusColor = device.isOnline ? '🟢' : '🔴';
    final typeIcon = device.isPhysical ? '📱' : '🖥️';

    _logger.info('$statusColor $typeIcon ${device.name}');
    _logger.info('   Platform: ${device.platform}');
    _logger.info('   ID: ${device.id}');
    _logger.info('   Status: ${device.isOnline ? 'Online' : 'Offline'}');
    _logger.info('   Type: ${device.isPhysical ? 'Physical' : 'Emulator'}');
    if (device.version != null) {
      _logger.info('   Version: ${device.version}');
    }
    _logger.info('');
  }

  void _showHelp(ArgParser parser) {
    _logger.info('''
${CliUtils.formatTitle('Flow CLI Device Management')}

${_localization.translate('commands.device')}

${CliUtils.formatSubtitle('Usage:')}
  flow device <command> [options]

${CliUtils.formatSubtitle('Commands:')}
  list        List available devices
  run         Run app on device
  logs        Show device logs
  install     Install app on device
  uninstall   Uninstall app from device
  hotreload   Start hot reload on device

${CliUtils.formatSubtitle('Options:')}
${parser.usage}

${CliUtils.formatSubtitle('Examples:')}
  flow device list
  flow device list --platform android
  flow device run --platform ios --client client1
  flow device logs --platform android
  flow device install --platform ios --client client1
  flow device uninstall --platform android --client client1
  flow device hotreload --platform ios --client client1
''');
  }
}
