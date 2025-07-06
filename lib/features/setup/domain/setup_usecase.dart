import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flow_cli/core/utils/cli_utils.dart';

class SetupUseCase {
  Future<String?> detectFlutterSdk() async {
    try {
      // Try to find Flutter in PATH
      final result = await Process.run('which', ['flutter']);
      if (result.exitCode == 0) {
        final flutterPath = result.stdout.toString().trim();
        if (flutterPath.isNotEmpty) {
          // Get the Flutter SDK root directory
          final flutterSdkPath = path.dirname(path.dirname(flutterPath));
          return flutterSdkPath;
        }
      }

      // Try common Flutter installation paths
      final commonPaths = [
        '/opt/flutter',
        '~/flutter',
        '~/Development/flutter',
        '/usr/local/flutter',
      ];

      for (final flutterPath in commonPaths) {
        final expandedPath =
            flutterPath.replaceAll('~', Platform.environment['HOME'] ?? '');
        final flutterBin = path.join(expandedPath, 'bin', 'flutter');

        if (File(flutterBin).existsSync()) {
          return expandedPath;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> createMultiClientStructure() async {
    final projectRoot = Directory.current.path;
    final assetsDir = Directory(path.join(projectRoot, 'assets'));
    final configsDir = Directory(path.join(assetsDir.path, 'configs'));

    // Create assets/configs directory
    await configsDir.create(recursive: true);

    // Create example client structure
    await _createExampleClient(configsDir.path, 'client1');

    CliUtils.printSuccess(
        'Multi-client structure created at: ${configsDir.path}');
  }

  Future<void> _createExampleClient(
      String configsPath, String clientName) async {
    final clientDir = Directory(path.join(configsPath, clientName));
    await clientDir.create(recursive: true);

    // Create example config.json
    final configFile = File(path.join(clientDir.path, 'config.json'));
    final exampleConfig = {
      'appName': 'Example App',
      'mainColor': '#2196F3',
      'assets': []
    };

    await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exampleConfig));

    // Create placeholder files
    await _createPlaceholderImage(
        path.join(clientDir.path, 'icon.png'), 1024, 1024);
    await _createPlaceholderImage(
        path.join(clientDir.path, 'splash.png'), 1242, 2436);

    CliUtils.printInfo('Created example client: $clientName');
  }

  Future<void> _createPlaceholderImage(
      String imagePath, int width, int height) async {
    final file = File(imagePath);

    // Create a simple placeholder text file (in real implementation, you'd create actual images)
    await file.writeAsString('''
# Placeholder for ${path.basename(imagePath)}
# Required dimensions: ${width}x$height
# Please replace this file with your actual image

This is a placeholder file. Replace it with your actual image file.
Required dimensions: ${width}x$height pixels
Format: PNG
''');
  }

  Future<bool> validateFlutterSdk(String flutterPath) async {
    try {
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');
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
}
