import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/core/utils/logger.dart';
import 'package:flow_cli/core/constants/app_constants.dart';

class BuildUseCase {
  final ConfigService _configService = ConfigService.instance;
  final _logger = AppLogger.instance;

  Future<bool> build({
    required String platform,
    required String buildMode,
    String? client,
    String? outputDir,
  }) async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      // Change to project directory
      final originalDir = Directory.current;
      Directory.current = Directory(projectPath);

      try {
        // Build command arguments
        final buildArgs = ['build', platform];

        // Add build mode if not default
        if (buildMode != 'debug') {
          buildArgs.add('--$buildMode');
        }

        // Add platform-specific arguments
        if (platform == 'android') {
          buildArgs.add('--split-per-abi');
        }

        // Add flavor for multi-client
        if (client != null) {
          buildArgs.addAll(['--flavor', client]);
        }

        CliUtils.printInfo('Running: flutter ${buildArgs.join(' ')}');

        // Execute build
        final result = await Process.run(
          flutterBin,
          buildArgs,
          workingDirectory: projectPath,
        );

        if (result.exitCode == 0) {
          CliUtils.printSuccess('Build completed successfully');

          // Copy output files if output directory is specified
          if (outputDir != null) {
            await _copyBuildOutputs(platform, buildMode, outputDir, client);
          }

          return true;
        } else {
          CliUtils.printError(
              'Build failed with exit code: ${result.exitCode}');
          _logger.error(result.stderr);
          return false;
        }
      } finally {
        Directory.current = originalDir;
      }
    } catch (e) {
      CliUtils.printError('Build error: $e');
      return false;
    }
  }

  Future<void> generateBranding(String client) async {
    try {
      final projectPath = _configService.projectPath!;
      final brandingScript =
          path.join(projectPath, AppConstants.brandingScript);

      if (!File(brandingScript).existsSync()) {
        CliUtils.printError('Branding script not found: $brandingScript');
        return;
      }

      CliUtils.printInfo('Generating branding for client: $client');

      final result = await Process.run(
        'python3',
        [brandingScript, client],
        workingDirectory: projectPath,
      );

      if (result.exitCode == 0) {
        CliUtils.printSuccess('Branding generated successfully');
      } else {
        CliUtils.printError('Branding generation failed');
        _logger.error(result.stderr);
      }
    } catch (e) {
      CliUtils.printError('Branding generation error: $e');
    }
  }

  Future<void> clean() async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      CliUtils.printInfo('Cleaning project...');

      final result = await Process.run(
        flutterBin,
        ['clean'],
        workingDirectory: projectPath,
      );

      if (result.exitCode == 0) {
        CliUtils.printSuccess('Project cleaned successfully');
      } else {
        CliUtils.printError('Clean failed');
        _logger.error(result.stderr);
      }
    } catch (e) {
      CliUtils.printError('Clean error: $e');
    }
  }

  Future<void> _copyBuildOutputs(String platform, String buildMode,
      String outputDir, String? client) async {
    try {
      final projectPath = _configService.projectPath!;
      final outputDirectory = Directory(outputDir);

      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
      }

      String sourcePath;
      String fileName;

      if (platform == 'android') {
        sourcePath =
            path.join(projectPath, 'build', 'app', 'outputs', 'flutter-apk');
        fileName = buildMode == 'release' ? 'app-release.apk' : 'app-debug.apk';

        if (client != null) {
          fileName = buildMode == 'release'
              ? 'app-$client-release.apk'
              : 'app-$client-debug.apk';
        }
      } else if (platform == 'ios') {
        sourcePath = path.join(projectPath, 'build', 'ios', 'iphoneos');
        fileName = 'Runner.app';
      } else {
        return;
      }

      final sourceFile = File(path.join(sourcePath, fileName));

      if (await sourceFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputFileName =
            '${path.basenameWithoutExtension(fileName)}_$timestamp${path.extension(fileName)}';
        final outputFile =
            File(path.join(outputDirectory.path, outputFileName));

        await sourceFile.copy(outputFile.path);
        CliUtils.printSuccess('Build output copied to: ${outputFile.path}');
      } else {
        CliUtils.printWarning('Build output not found: ${sourceFile.path}');
      }
    } catch (e) {
      CliUtils.printError('Error copying build outputs: $e');
    }
  }

  Future<List<String>> getAvailableTargets() async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      final result = await Process.run(
        flutterBin,
        ['build', '--help'],
        workingDirectory: projectPath,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final targets = <String>[];

        // Parse available build targets from help output
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.trim().startsWith('Available subcommands:')) {
            // Start parsing targets
            continue;
          }

          final match = RegExp(r'^\s+(\w+)\s+').firstMatch(line);
          if (match != null) {
            final target = match.group(1)!;
            if (AppConstants.supportedPlatforms.contains(target)) {
              targets.add(target);
            }
          }
        }

        return targets;
      }

      return AppConstants.supportedPlatforms;
    } catch (e) {
      return AppConstants.supportedPlatforms;
    }
  }
}
