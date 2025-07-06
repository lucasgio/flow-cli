import 'dart:io';
import 'package:args/args.dart';
import 'package:interact/interact.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/core/utils/logger.dart';
import 'package:flow_cli/shared/services/localization_service.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/features/setup/domain/setup_usecase.dart';

class SetupHandler {
  final SetupUseCase _setupUseCase = SetupUseCase();
  final LocalizationService _localization = LocalizationService.instance;
  final ConfigService _configService = ConfigService.instance;
  final _logger = AppLogger.instance;

  Future<void> handle(List<String> args) async {
    final parser = ArgParser()
      ..addFlag('multi-client',
          help: 'Setup for multi-client configuration', negatable: false)
      ..addFlag('help',
          abbr: 'h', help: 'Show help for setup command', negatable: false);

    try {
      final results = parser.parse(args);

      if (results['help']) {
        _showHelp(parser);
        return;
      }

      CliUtils.printInfo(_localization.translate('setup.welcome'));
      CliUtils.printSeparator();

      // Check if multi-client is needed
      bool multiClient = results['multi-client'] as bool;

      if (!multiClient) {
        multiClient = Confirm(
          prompt: _localization.translate('setup.multi_client'),
          defaultValue: false,
        ).interact();
      }

      if (multiClient) {
        await _setupMultiClient();
      }

      // Configure language
      await _configureLanguage();

      // Configure Flutter SDK
      await _configureFlutterSdk();

      // Configure project path
      await _configureProjectPath();

      // Save configuration
      await _configService.saveConfig();

      CliUtils.printSuccess(_localization.translate('setup.complete'));
    } catch (e) {
      CliUtils.printError('Setup failed: $e');
      exit(1);
    }
  }

  Future<void> _setupMultiClient() async {
    CliUtils.printInfo(_localization.translate('setup.multi_client_guide'));

    _logger.info('''
${_localization.translate('setup.folder_structure')}

assets/
  configs/
    client1/
      ├── icon.png (1024x1024)
      ├── splash.png (1242x2436)
      └── config.json
    client2/
      ├── icon.png
      ├── splash.png
      └── config.json

${_localization.translate('setup.branding_info')}
- icon.png: App icon (1024x1024 pixels)
- splash.png: Splash screen (1242x2436 pixels)
- config.json: Configuration file with:
  {
    "appName": "Your App Name",
    "mainColor": "#FF0000",
    "assets": []
  }
''');

    await _setupUseCase.createMultiClientStructure();
    CliUtils.printSuccess('Multi-client structure created!');
  }

  Future<void> _configureLanguage() async {
    final languageIndex = Select(
      prompt: 'Select language / Seleccionar idioma:',
      options: ['English', 'Español'],
    ).interact();

    final langCode = languageIndex == 0 ? 'en' : 'es';
    await _localization.initialize(langCode);
    _configService.setLanguage(langCode);
  }

  Future<void> _configureFlutterSdk() async {
    final flutterPath = await _setupUseCase.detectFlutterSdk();

    if (flutterPath != null) {
      CliUtils.printSuccess('Flutter SDK found at: $flutterPath');
      _configService.setFlutterPath(flutterPath);
    } else {
      CliUtils.printWarning('Flutter SDK not found automatically');
      final manualPath = Input(
        prompt: 'Please enter Flutter SDK path:',
        validator: (path) {
          if (path.isEmpty) return false;
          if (!Directory(path).existsSync()) return false;
          return true;
        },
      ).interact();

      _configService.setFlutterPath(manualPath);
    }
  }

  Future<void> _configureProjectPath() async {
    final currentDir = Directory.current.path;
    final useCurrentDir = Confirm(
      prompt: 'Use current directory as project path? ($currentDir)',
      defaultValue: true,
    ).interact();

    if (useCurrentDir) {
      _configService.setProjectPath(currentDir);
    } else {
      final projectPath = Input(
        prompt: 'Enter project path:',
        validator: (path) {
          if (path.isEmpty) return false;
          if (!Directory(path).existsSync()) return false;
          return true;
        },
      ).interact();

      _configService.setProjectPath(projectPath);
    }
  }

  void _showHelp(ArgParser parser) {
    print('''
${CliUtils.formatTitle('Flow CLI Setup')}

${_localization.translate('commands.setup')}

${CliUtils.formatSubtitle('Usage:')}
  flow setup [options]

${CliUtils.formatSubtitle('Options:')}
${parser.usage}

${CliUtils.formatSubtitle('Examples:')}
  flow setup
  flow setup --multi-client
''');
  }
}
