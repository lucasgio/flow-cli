import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/core/utils/logger.dart';
import 'package:flow_cli/shared/models/device_model.dart';

class DeviceUseCase {
  final ConfigService _configService = ConfigService.instance;
  final _logger = AppLogger.instance;

  Future<List<DeviceModel>> getDevices({String? platform}) async {
    final devices = <DeviceModel>[];

    try {
      // Get Flutter devices
      final flutterDevices = await _getFlutterDevices();
      devices.addAll(flutterDevices);

      // Filter by platform if specified
      if (platform != null) {
        return devices.where((d) => d.platform == platform).toList();
      }

      return devices;
    } catch (e) {
      CliUtils.printError('Error getting devices: $e');
      return [];
    }
  }

  Future<List<DeviceModel>> _getFlutterDevices() async {
    try {
      final flutterPath = _configService.flutterPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      final result = await Process.run(
        flutterBin,
        ['devices', '--machine'],
        workingDirectory: _configService.projectPath,
      );

      if (result.exitCode != 0) {
        CliUtils.printError('Failed to get Flutter devices');
        return [];
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) return [];

      final List<dynamic> deviceData = jsonDecode(output);

      return deviceData.map((data) {
        final deviceMap = data as Map<String, dynamic>;
        return DeviceModel(
          id: deviceMap['id'] as String,
          name: deviceMap['name'] as String,
          platform: _mapPlatform(deviceMap['platform'] as String),
          isPhysical: deviceMap['isDevice'] as bool? ?? false,
          isOnline: deviceMap['isAvailable'] as bool? ?? false,
          version: deviceMap['platformVersion'] as String?,
          architecture: deviceMap['targetPlatform'] as String?,
          additionalInfo: deviceMap,
        );
      }).toList();
    } catch (e) {
      CliUtils.printError('Error parsing Flutter devices: $e');
      return [];
    }
  }

  String _mapPlatform(String flutterPlatform) {
    switch (flutterPlatform.toLowerCase()) {
      case 'android':
        return 'android';
      case 'ios':
        return 'ios';
      case 'macos':
        return 'macos';
      case 'windows':
        return 'windows';
      case 'linux':
        return 'linux';
      case 'web':
        return 'web';
      default:
        return flutterPlatform;
    }
  }

  Future<bool> runOnDevice(DeviceModel device,
      {String? client, List<String>? additionalArgs}) async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      final args = ['run', '--device-id', device.id];

      // Add flavor for multi-client
      if (client != null) {
        args.addAll(['--flavor', client]);
      }

      // Add additional arguments
      if (additionalArgs != null) {
        args.addAll(additionalArgs);
      }

      CliUtils.printInfo('Running: flutter ${args.join(' ')}');

      final result = await Process.run(
        flutterBin,
        args,
        workingDirectory: projectPath,
      );

      if (result.exitCode == 0) {
        return true;
      } else {
        CliUtils.printError('Failed to run on device');
        _logger.error(result.stderr);
        return false;
      }
    } catch (e) {
      CliUtils.printError('Error running on device: $e');
      return false;
    }
  }

  Future<bool> installApp(DeviceModel device, {String? client}) async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      final args = ['install', '--device-id', device.id];

      // Add flavor for multi-client
      if (client != null) {
        args.addAll(['--flavor', client]);
      }

      CliUtils.printInfo('Installing app on device: ${device.name}');

      final result = await Process.run(
        flutterBin,
        args,
        workingDirectory: projectPath,
      );

      return result.exitCode == 0;
    } catch (e) {
      CliUtils.printError('Error installing app: $e');
      return false;
    }
  }

  Future<bool> uninstallApp(DeviceModel device, {String? client}) async {
    try {
      // Get app package name
      final packageName = await _getAppPackageName(client);
      if (packageName == null) {
        CliUtils.printError('Could not determine app package name');
        return false;
      }

      if (device.platform == 'android') {
        return await _uninstallAndroidApp(device, packageName);
      } else if (device.platform == 'ios') {
        return await _uninstallIOSApp(device, packageName);
      } else {
        CliUtils.printError(
            'Uninstall not supported for platform: ${device.platform}');
        return false;
      }
    } catch (e) {
      CliUtils.printError('Error uninstalling app: $e');
      return false;
    }
  }

  Future<String?> _getAppPackageName(String? client) async {
    try {
      final projectPath = _configService.projectPath!;

      if (client != null) {
        // Try to get package name from client config
        final configPath =
            path.join(projectPath, 'assets', 'configs', client, 'config.json');
        final configFile = File(configPath);

        if (await configFile.exists()) {
          final content = await configFile.readAsString();
          final config = jsonDecode(content) as Map<String, dynamic>;
          return config['packageName'] as String?;
        }
      }

      // Fallback to default package name
      return 'com.example.app'; // You should extract this from pubspec.yaml or Android manifest
    } catch (e) {
      return null;
    }
  }

  Future<bool> _uninstallAndroidApp(
      DeviceModel device, String packageName) async {
    try {
      final result = await Process.run(
        'adb',
        ['-s', device.id, 'uninstall', packageName],
      );

      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _uninstallIOSApp(DeviceModel device, String packageName) async {
    try {
      // iOS uninstall is more complex and requires additional tools
      // For now, we'll just return false as it's not easily implemented
      CliUtils.printWarning(
          'iOS app uninstall requires manual removal or additional tools');
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> showLogs(DeviceModel device) async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      CliUtils.printInfo('Showing logs for device: ${device.name}');
      CliUtils.printInfo('Press Ctrl+C to stop');

      final process = await Process.start(
        flutterBin,
        ['logs', '--device-id', device.id],
        workingDirectory: projectPath,
      );

      // Stream logs to console
      process.stdout.transform(utf8.decoder).listen((data) {
        _logger.info(data);
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        _logger.error(data);
      });

      await process.exitCode;
    } catch (e) {
      CliUtils.printError('Error showing logs: $e');
    }
  }

  Future<bool> isDeviceOnline(DeviceModel device) async {
    try {
      final devices = await getDevices();
      final updatedDevice = devices.firstWhere(
        (d) => d.id == device.id,
        orElse: () => device,
      );

      return updatedDevice.isOnline;
    } catch (e) {
      return false;
    }
  }
}
