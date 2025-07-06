import 'dart:io';
import 'package:args/args.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/localization_service.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/features/build/domain/build_usecase.dart';
import 'package:flow_cli/core/constants/app_constants.dart';

class BuildHandler {
  final BuildUseCase _buildUseCase = BuildUseCase();
  final LocalizationService _localization = LocalizationService.instance;
  final ConfigService _configService = ConfigService.instance;
  
  Future<void> handle(List<String> args) async {
    final parser = ArgParser()
      ..addFlag('debug', help: 'Build in debug mode', negatable: false)
      ..addFlag('release', help: 'Build in release mode', negatable: false)
      ..addFlag('profile', help: 'Build in profile mode', negatable: false)
      ..addOption('client', help: 'Client name for multi-client builds')
      ..addOption('output', help: 'Output directory for built files')
      ..addFlag('clean', help: 'Clean before building', negatable: false)
      ..addFlag('help', abbr: 'h', help: 'Show help for build command', negatable: false);
    
    try {
      final results = parser.parse(args);
      
      if (results['help']) {
        _showHelp(parser);
        return;
      }
      
      // Check if Flutter is configured
      if (!_configService.isConfigured) {
        CliUtils.printError('Flow CLI is not configured. Please run: flow setup');
        exit(1);
      }
      
      // Validate platform
      if (results.rest.isEmpty) {
        CliUtils.printError(_localization.translate('build.platform_required'));
        exit(1);
      }
      
      final platform = results.rest[0];
      if (!AppConstants.supportedPlatforms.contains(platform)) {
        CliUtils.printError('Unsupported platform: $platform');
        CliUtils.printInfo('Supported platforms: ${AppConstants.supportedPlatforms.join(', ')}');
        exit(1);
      }
      
      // Determine build mode
      String buildMode = AppConstants.defaultBuildMode;
      if (results['release']) buildMode = 'release';
      else if (results['profile']) buildMode = 'profile';
      else if (results['debug']) buildMode = 'debug';
      
      // Handle multi-client
      String? client = results['client'];
      if (_configService.multiClient && client == null) {
        CliUtils.printError('Multi-client mode requires --client parameter');
        CliUtils.printInfo('Available clients: ${_configService.clients.join(', ')}');
        exit(1);
      }
      
      CliUtils.printInfo(_localization.translate('build.starting'));
      CliUtils.printInfo('Platform: $platform');
      CliUtils.printInfo('Build mode: $buildMode');
      if (client != null) CliUtils.printInfo('Client: $client');
      
      // Clean if requested
      if (results['clean']) {
        await _buildUseCase.clean();
      }
      
      // Run branding generation for multi-client
      if (_configService.multiClient && client != null) {
        await _buildUseCase.generateBranding(client);
      }
      
      // Build the application
      final success = await _buildUseCase.build(
        platform: platform,
        buildMode: buildMode,
        client: client,
        outputDir: results['output'],
      );
      
      if (success) {
        CliUtils.printSuccess(_localization.translate('build.success'));
      } else {
        CliUtils.printError(_localization.translate('build.failed'));
        exit(1);
      }
      
    } catch (e) {
      CliUtils.printError('Build failed: $e');
      exit(1);
    }
  }
  
  void _showHelp(ArgParser parser) {
    print('''
${CliUtils.formatTitle('Flow CLI Build')}

${_localization.translate('commands.build')}

${CliUtils.formatSubtitle('Usage:')}
  flow build <platform> [options]

${CliUtils.formatSubtitle('Platforms:')}
  android    Build for Android
  ios        Build for iOS
  web        Build for Web

${CliUtils.formatSubtitle('Options:')}
${parser.usage}

${CliUtils.formatSubtitle('Examples:')}
  flow build android --debug
  flow build ios --release
  flow build web --release
  flow build android --client client1 --debug
  flow build ios --release --clean
  flow build web --output ./web-build/
''');
  }
}