import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/shared/models/config_model.dart';

class ConfigUseCase {
  final ConfigService _configService = ConfigService.instance;

  Future<bool> validateFlutterSdk(String flutterPath) async {
    try {
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');
      final flutterFile = File(flutterBin);

      if (!await flutterFile.exists()) {
        return false;
      }

      final result = await Process.run(flutterBin, ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getFlutterVersion(String flutterPath) async {
    try {
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');
      final result = await Process.run(flutterBin, ['--version']);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final versionMatch = RegExp(r'Flutter ([\d.]+)').firstMatch(output);
        return versionMatch?.group(1);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> resetConfiguration() async {
    try {
      // Create a new default config
      final defaultConfig = ConfigModel.defaultConfig();

      // Save the default config (this will replace the current one)
      _configService.setLanguage(defaultConfig.language);
      _configService.setMultiClient(defaultConfig.multiClient);

      // Save the reset configuration
      await _configService.saveConfig();
    } catch (e) {
      CliUtils.printError('Failed to reset configuration: $e');
      rethrow;
    }
  }

  Future<void> createClientStructure(String clientName) async {
    try {
      final projectPath = _configService.projectPath;
      if (projectPath == null) {
        CliUtils.printError('Project path not configured');
        return;
      }

      final clientDir =
          Directory(path.join(projectPath, 'assets', 'configs', clientName));
      await clientDir.create(recursive: true);

      // Create example config.json
      final configFile = File(path.join(clientDir.path, 'config.json'));
      final exampleConfig = {
        'appName': clientName.toUpperCase(),
        'mainColor': '#2196F3',
        'packageName': 'com.example.$clientName',
        'assets': []
      };

      await configFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(exampleConfig));

      // Create placeholder image files
      await _createPlaceholderFile(path.join(clientDir.path, 'icon.png'),
          'App Icon Placeholder', 'Required dimensions: 1024x1024 pixels');

      await _createPlaceholderFile(path.join(clientDir.path, 'splash.png'),
          'Splash Screen Placeholder', 'Required dimensions: 1242x2436 pixels');

      CliUtils.printSuccess('Client structure created at: ${clientDir.path}');
    } catch (e) {
      CliUtils.printError('Failed to create client structure: $e');
      rethrow;
    }
  }

  Future<void> _createPlaceholderFile(
      String filePath, String title, String description) async {
    final file = File(filePath);
    await file.writeAsString('''
# $title
# $description
# Please replace this file with your actual image file.

This is a placeholder file for: ${path.basename(filePath)}
$description
Format: PNG
''');
  }

  Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final info = <String, dynamic>{};

      // Get Dart version
      final dartResult = await Process.run('dart', ['--version']);
      if (dartResult.exitCode == 0) {
        info['dart_version'] = dartResult.stdout.toString().trim();
      }

      // Get Flutter version if configured
      final flutterPath = _configService.flutterPath;
      if (flutterPath != null) {
        final flutterVersion = await getFlutterVersion(flutterPath);
        info['flutter_version'] = flutterVersion;
      }

      // Get OS info
      info['platform'] = Platform.operatingSystem;
      info['os_version'] = Platform.operatingSystemVersion;

      return info;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<bool> validateProjectStructure(String projectPath) async {
    try {
      final projectDir = Directory(projectPath);
      if (!await projectDir.exists()) {
        return false;
      }

      // Check for essential Flutter files
      final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
      final libDir = Directory(path.join(projectPath, 'lib'));

      return await pubspecFile.exists() && await libDir.exists();
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getAvailableClients() async {
    try {
      final projectPath = _configService.projectPath;
      if (projectPath == null) return [];

      final configsDir = Directory(path.join(projectPath, 'assets', 'configs'));
      if (!await configsDir.exists()) return [];

      final clients = <String>[];
      await for (final entity in configsDir.list()) {
        if (entity is Directory) {
          final clientName = path.basename(entity.path);
          final configFile = File(path.join(entity.path, 'config.json'));

          if (await configFile.exists()) {
            clients.add(clientName);
          }
        }
      }

      return clients;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getClientConfig(String clientName) async {
    try {
      final projectPath = _configService.projectPath;
      if (projectPath == null) return null;

      final configFile = File(path.join(
          projectPath, 'assets', 'configs', clientName, 'config.json'));

      if (!await configFile.exists()) return null;

      final content = await configFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateClientConfig(
      String clientName, Map<String, dynamic> config) async {
    try {
      final projectPath = _configService.projectPath;
      if (projectPath == null) {
        throw Exception('Project path not configured');
      }

      final configFile = File(path.join(
          projectPath, 'assets', 'configs', clientName, 'config.json'));

      await configFile
          .writeAsString(const JsonEncoder.withIndent('  ').convert(config));

      CliUtils.printSuccess('Client configuration updated: $clientName');
    } catch (e) {
      CliUtils.printError('Failed to update client configuration: $e');
      rethrow;
    }
  }

  Future<bool> isFlutterProject(String projectPath) async {
    try {
      final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
      if (!await pubspecFile.exists()) return false;

      final content = await pubspecFile.readAsString();
      return content.contains('flutter:');
    } catch (e) {
      return false;
    }
  }

  Future<void> backupConfiguration() async {
    try {
      final configFile = await _configService.getConfigFile();
      if (!await configFile.exists()) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File('${configFile.path}.backup.$timestamp');

      await configFile.copy(backupFile.path);
      CliUtils.printSuccess('Configuration backed up to: ${backupFile.path}');
    } catch (e) {
      CliUtils.printError('Failed to backup configuration: $e');
    }
  }

  Future<void> restoreConfiguration(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found');
      }

      final configFile = await _configService.getConfigFile();
      await backupFile.copy(configFile.path);

      // Reload configuration
      await _configService.initialize();

      CliUtils.printSuccess('Configuration restored from backup');
    } catch (e) {
      CliUtils.printError('Failed to restore configuration: $e');
      rethrow;
    }
  }
}
