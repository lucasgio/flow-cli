import 'dart:io';
import 'package:args/args.dart';
import 'package:interact/interact.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/core/utils/logger.dart';
import 'package:flow_cli/shared/services/localization_service.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/features/config/domain/config_usecase.dart';

class ConfigHandler {
  final ConfigUseCase _configUseCase = ConfigUseCase();
  final LocalizationService _localization = LocalizationService.instance;
  final ConfigService _configService = ConfigService.instance;
  final _logger = AppLogger.instance;

  Future<void> handle(List<String> args) async {
    final parser = ArgParser()
      ..addFlag('list', help: 'List all configuration values', negatable: false)
      ..addFlag('reset',
          help: 'Reset configuration to defaults', negatable: false)
      ..addFlag('help',
          abbr: 'h', help: 'Show help for config command', negatable: false);

    try {
      final results = parser.parse(args);

      if (results['help']) {
        _showHelp(parser);
        return;
      }

      if (results['list']) {
        await _listConfiguration();
        return;
      }

      if (results['reset']) {
        await _resetConfiguration();
        return;
      }

      if (results.rest.isEmpty) {
        _showHelp(parser);
        return;
      }

      final command = results.rest[0];
      final value = results.rest.length > 1 ? results.rest[1] : null;

      switch (command) {
        case 'flutter-path':
          await _setFlutterPath(value);
          break;
        case 'project-path':
          await _setProjectPath(value);
          break;
        case 'language':
          await _setLanguage(value);
          break;
        case 'multi-client':
          await _setMultiClient(value);
          break;
        case 'add-client':
          await _addClient(value);
          break;
        case 'remove-client':
          await _removeClient(value);
          break;
        case 'current-client':
          await _setCurrentClient(value);
          break;
        default:
          CliUtils.printError('Unknown config command: $command');
          _showHelp(parser);
          exit(1);
      }
    } catch (e) {
      CliUtils.printError('Configuration failed: $e');
      exit(1);
    }
  }

  Future<void> _listConfiguration() async {
    _logger.info(CliUtils.formatTitle('Current Configuration'));
    CliUtils.printSeparator();

    _logger.info('Language: ${_configService.language}');
    _logger.info('Flutter Path: ${_configService.flutterPath ?? 'Not set'}');
    _logger.info('Project Path: ${_configService.projectPath ?? 'Not set'}');
    _logger.info('Multi-client: ${_configService.multiClient}');
    _logger.info('Current Client: ${_configService.currentClient ?? 'Not set'}');
    _logger.info('Available Clients: ${_configService.clients.join(', ')}');

    CliUtils.printSeparator();
    _logger.info(
        'Configuration Status: ${_configService.isConfigured ? 'Complete' : 'Incomplete'}');
  }

  Future<void> _resetConfiguration() async {
    final confirm = Confirm(
      prompt: 'Are you sure you want to reset all configuration?',
      defaultValue: false,
    ).interact();

    if (!confirm) {
      CliUtils.printInfo('Configuration reset cancelled');
      return;
    }

    await _configUseCase.resetConfiguration();
    CliUtils.printSuccess('Configuration reset successfully');
  }

  Future<void> _setFlutterPath(String? value) async {
    String flutterPath;

    if (value != null) {
      flutterPath = value;
    } else {
      flutterPath = Input(
        prompt: '${_localization.translate('config.flutter_path')}:',
        validator: (path) {
          if (path.isEmpty) return false;
          if (!Directory(path).existsSync()) return false;
          return true;
        },
      ).interact();
    }

    // Validate Flutter SDK
    final isValid = await _configUseCase.validateFlutterSdk(flutterPath);
    if (!isValid) {
      CliUtils.printError(_localization.translate('config.flutter_not_found'));
      exit(1);
    }

    _configService.setFlutterPath(flutterPath);
    await _configService.saveConfig();

    CliUtils.printSuccess(_localization.translate('config.saved'));

    // Show Flutter version
    final version = await _configUseCase.getFlutterVersion(flutterPath);
    if (version != null) {
      CliUtils.printInfo('Flutter version: $version');
    }
  }

  Future<void> _setProjectPath(String? value) async {
    String projectPath;

    if (value != null) {
      projectPath = value;
    } else {
      projectPath = Input(
        prompt: '${_localization.translate('config.project_path')}:',
        validator: (path) {
          if (path.isEmpty) return false;
          if (!Directory(path).existsSync()) return false;
          return true;
        },
      ).interact();
    }

    _configService.setProjectPath(projectPath);
    await _configService.saveConfig();

    CliUtils.printSuccess(_localization.translate('config.saved'));
  }

  Future<void> _setLanguage(String? value) async {
    String language;

    if (value != null) {
      language = value;
    } else {
      final selectionIndex = Select(
        prompt: 'Select language:',
        options: ['English (en)', 'Español (es)'],
      ).interact();

      language = selectionIndex == 0 ? 'en' : 'es';
    }

    if (!['en', 'es'].contains(language)) {
      CliUtils.printError('Unsupported language: $language');
      exit(1);
    }

    _configService.setLanguage(language);
    await _configService.saveConfig();
    await _localization.initialize(language);

    CliUtils.printSuccess(_localization.translate('config.saved'));
  }

  Future<void> _setMultiClient(String? value) async {
    bool multiClient;

    if (value != null) {
      multiClient = value.toLowerCase() == 'true';
    } else {
      multiClient = Confirm(
        prompt: 'Enable multi-client mode?',
        defaultValue: _configService.multiClient,
      ).interact();
    }

    _configService.setMultiClient(multiClient);
    await _configService.saveConfig();

    CliUtils.printSuccess(_localization.translate('config.saved'));

    if (multiClient && _configService.clients.isEmpty) {
      CliUtils.printInfo(
          'Multi-client mode enabled. Add clients using: flow config add-client <name>');
    }
  }

  Future<void> _addClient(String? value) async {
    String clientName;

    if (value != null) {
      clientName = value;
    } else {
      clientName = Input(
        prompt: 'Enter client name:',
        validator: (name) {
          if (name.isEmpty) return false;
          if (_configService.clients.contains(name)) return false;
          return true;
        },
      ).interact();
    }

    _configService.addClient(clientName);
    await _configService.saveConfig();

    CliUtils.printSuccess('Client "$clientName" added successfully');

    // Ask if they want to create the client structure
    final createStructure = Confirm(
      prompt: 'Create client structure for "$clientName"?',
      defaultValue: true,
    ).interact();

    if (createStructure) {
      await _configUseCase.createClientStructure(clientName);
      CliUtils.printSuccess('Client structure created for "$clientName"');
    }
  }

  Future<void> _removeClient(String? value) async {
    if (_configService.clients.isEmpty) {
      CliUtils.printWarning('No clients configured');
      return;
    }

    String clientName;

    if (value != null) {
      clientName = value;
    } else {
      final selectionIndex = Select(
        prompt: 'Select client to remove:',
        options: _configService.clients,
      ).interact();
      clientName = _configService.clients[selectionIndex];
    }

    if (!_configService.clients.contains(clientName)) {
      CliUtils.printError('Client "$clientName" not found');
      exit(1);
    }

    final confirm = Confirm(
      prompt: 'Are you sure you want to remove client "$clientName"?',
      defaultValue: false,
    ).interact();

    if (!confirm) {
      CliUtils.printInfo('Client removal cancelled');
      return;
    }

    _configService.removeClient(clientName);

    // Reset current client if it was the removed one
    if (_configService.currentClient == clientName) {
      _configService.setCurrentClient(null);
    }

    await _configService.saveConfig();

    CliUtils.printSuccess('Client "$clientName" removed successfully');
  }

  Future<void> _setCurrentClient(String? value) async {
    if (_configService.clients.isEmpty) {
      CliUtils.printWarning('No clients configured');
      return;
    }

    String clientName;

    if (value != null) {
      clientName = value;
    } else {
      final options = ['None', ..._configService.clients];
      final selectionIndex = Select(
        prompt: 'Select current client:',
        options: options,
      ).interact();

      clientName = selectionIndex == 0 ? '' : options[selectionIndex];
    }

    if (clientName.isNotEmpty && !_configService.clients.contains(clientName)) {
      CliUtils.printError('Client "$clientName" not found');
      exit(1);
    }

    _configService.setCurrentClient(clientName.isEmpty ? null : clientName);
    await _configService.saveConfig();

    CliUtils.printSuccess(_localization.translate('config.saved'));
  }

  void _showHelp(ArgParser parser) {
    _logger.info('''
${CliUtils.formatTitle('Flow CLI Configuration')}

${_localization.translate('commands.config')}

${CliUtils.formatSubtitle('Usage:')}
  flow config <command> [options]

${CliUtils.formatSubtitle('Commands:')}
  list              Show current configuration
  reset             Reset all configuration
  flutter-path      Set Flutter SDK path
  project-path      Set project path
  language          Set language (en/es)
  multi-client      Enable/disable multi-client mode
  add-client        Add a new client
  remove-client     Remove a client
  set-client        Set current client

${CliUtils.formatSubtitle('Options:')}
${parser.usage}

${CliUtils.formatSubtitle('Examples:')}
  flow config list
  flow config flutter-path /path/to/flutter
  flow config project-path /path/to/project
  flow config language en
  flow config multi-client true
  flow config add-client client1
  flow config remove-client client1
  flow config set-client client1
''');
  }
}
