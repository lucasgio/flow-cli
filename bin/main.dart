import 'dart:io';
import 'package:args/args.dart';
import 'package:flow_cli/core/constants/app_constants.dart';
import 'package:flow_cli/features/setup/presentation/setup_handler.dart';
import 'package:flow_cli/features/build/presentation/build_handler.dart';
import 'package:flow_cli/features/device/presentation/device_handler.dart';
import 'package:flow_cli/features/analyze/presentation/analyze_handler.dart';
import 'package:flow_cli/features/config/presentation/config_handler.dart';
import 'package:flow_cli/features/hotreload/presentation/hotreload_handler.dart';
import 'package:flow_cli/features/web/presentation/web_handler.dart';
import 'package:flow_cli/shared/services/localization_service.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', help: 'Show this help message', negatable: false)
    ..addFlag('version',
        abbr: 'v', help: 'Show version information', negatable: false)
    ..addOption('language',
        abbr: 'l', help: 'Set language (en/es)', defaultsTo: 'en');

  try {
    final results = parser.parse(arguments);

    // Initialize configuration
    await ConfigService.instance.initialize();

    // Initialize localization
    await LocalizationService.instance.initialize(results['language']);

    if (results['help'] && results.rest.isEmpty) {
      _showHelp(parser);
      return;
    }

    if (results['version']) {
      _showVersion();
      return;
    }

    final command = results.rest.isNotEmpty ? results.rest[0] : '';
    final subArgs = results.rest.skip(1).toList();

    switch (command) {
      case 'setup':
        await SetupHandler().handle(subArgs);
        break;
      case 'build':
        await BuildHandler().handle(subArgs);
        break;
      case 'device':
        await DeviceHandler().handle(subArgs);
        break;
      case 'analyze':
        await AnalyzeHandler().handle(subArgs);
        break;
      case 'config':
        await ConfigHandler().handle(subArgs);
        break;
      case 'hotreload':
        await HotReloadHandler().handle(subArgs);
        break;
      case 'web':
        await WebHandler().handle(subArgs);
        break;
      default:
        CliUtils.printError('Unknown command: $command');
        _showHelp(parser);
        exit(1);
    }
  } catch (e) {
    CliUtils.printError('Error: $e');
    exit(1);
  }
}

void _showHelp(ArgParser parser) {
  final localization = LocalizationService.instance;
  CliUtils.printInfo('''
${CliUtils.formatTitle('Flow CLI v${AppConstants.version}')}

${localization.translate('help.description')}

${CliUtils.formatSubtitle('Usage:')}
  flow <command> [options]

${CliUtils.formatSubtitle('Commands:')}
  setup     ${localization.translate('commands.setup')}
  build     ${localization.translate('commands.build')}
  device    ${localization.translate('commands.device')}
  analyze   ${localization.translate('commands.analyze')}
  config    ${localization.translate('commands.config')}
  hotreload ${localization.translate('commands.hotreload')}
  web       ${localization.translate('commands.web')}

${CliUtils.formatSubtitle('Global Options:')}
${parser.usage}

${CliUtils.formatSubtitle('Examples:')}
  flow setup --multi-client
  flow build android --debug
  flow device list
  flow hotreload --client client1
  flow web serve --port 8080
  flow analyze --optimize
  flow config flutter-path /path/to/flutter

${localization.translate('help.more_info')}
''');
}

void _showVersion() {
  CliUtils.printInfo('Flow CLI v${AppConstants.version}');
}
