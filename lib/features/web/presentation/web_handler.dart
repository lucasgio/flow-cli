import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:interact/interact.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/core/utils/logger.dart';
import 'package:flow_cli/shared/services/localization_service.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/features/web/domain/web_usecase.dart';

class WebHandler {
  final WebUseCase _webUseCase = WebUseCase();
  final LocalizationService _localization = LocalizationService.instance;
  final ConfigService _configService = ConfigService.instance;
  final _logger = AppLogger.instance;

  Future<void> handle(List<String> args) async {
    final parser = ArgParser()
      ..addOption('port',
          abbr: 'p', help: 'Development server port', defaultsTo: '3000')
      ..addOption('hostname',
          help: 'Development server hostname', defaultsTo: 'localhost')
      ..addOption('client', help: 'Client name for multi-client apps')
      ..addOption('output',
          help: 'Output directory for build', defaultsTo: 'build/web')
      ..addFlag('release', help: 'Build in release mode', negatable: false)
      ..addFlag('profile', help: 'Build in profile mode', negatable: false)
      ..addFlag('pwa', help: 'Enable PWA features', negatable: false)
      ..addFlag('wasm',
          help: 'Enable WebAssembly compilation', negatable: false)
      ..addFlag('tree-shake-icons',
          help: 'Tree shake icons', negatable: true, defaultsTo: true)
      ..addFlag('source-maps',
          help: 'Generate source maps', negatable: true, defaultsTo: true)
      ..addFlag('verbose', abbr: 'v', help: 'Verbose output', negatable: false)
      ..addFlag('auto-open',
          help: 'Auto open browser', negatable: true, defaultsTo: true)
      ..addFlag('help',
          abbr: 'h', help: 'Show help for web command', negatable: false);

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

      final command = results.rest.isNotEmpty ? results.rest[0] : 'serve';

      switch (command) {
        case 'serve':
          await _serveDevelopment(results);
          break;
        case 'build':
          await _buildWeb(results);
          break;
        case 'deploy':
          await _deployWeb(results);
          break;
        case 'analyze':
          await _analyzeWeb(results);
          break;
        case 'pwa':
          await _configurePWA(results);
          break;
        case 'optimize':
          await _optimizeWeb(results);
          break;
        default:
          CliUtils.printError('Unknown web command: $command');
          _showHelp(parser);
          exit(1);
      }
    } catch (e) {
      CliUtils.printError('Web command failed: $e');
      exit(1);
    }
  }

  Future<void> _serveDevelopment(ArgResults results) async {
    final port = int.tryParse(results['port']) ?? 3000;
    final hostname = results['hostname'] as String;
    final client = results['client'] as String?;
    final verbose = results['verbose'] as bool;
    final autoOpen = results['auto-open'] as bool;

    // Handle multi-client requirement
    if (_configService.multiClient && client == null) {
      CliUtils.printError('Multi-client mode requires --client parameter');
      CliUtils.printInfo(
          'Available clients: ${_configService.clients.join(', ')}');
      exit(1);
    }

    _logger.info('Starting Flutter web development server...');
    _logger.info('Port: $port');
    _logger.info('Hostname: $hostname');
    if (client != null) _logger.info('Client: $client');

    // Start the development server
    final serverSession = await _webUseCase.startDevelopmentServer(
      port: port,
      hostname: hostname,
      client: client,
      verbose: verbose,
      autoOpen: autoOpen,
    );

    if (serverSession == null) {
      _logger.error('Failed to start development server');
      exit(1);
    }

    _printWebServerInstructions(hostname, port);

    // Set up keyboard input handling
    stdin.echoMode = false;
    stdin.lineMode = false;

    // Start log streaming
    late StreamSubscription<WebLogEntry> logSubscription;
    late StreamSubscription<List<int>> keyboardSubscription;

    logSubscription =
        _webUseCase.getLogStream(serverSession).listen((logEntry) {
      _printWebLogEntry(logEntry, verbose);
    });

    // Handle keyboard input
    keyboardSubscription = stdin.listen((data) async {
      final key = String.fromCharCodes(data).toLowerCase();

      switch (key) {
        case 'r':
          await _performHotReload(serverSession);
          break;
        case 'R':
          await _performHotRestart(serverSession);
          break;
        case 'o':
          await _openBrowser(hostname, port);
          break;
        case 'h':
          _printWebServerInstructions(hostname, port);
          break;
        case 'c':
          _clearConsole();
          break;
        case 'l':
          await _showWebLogs(serverSession);
          break;
        case 'p':
          await _showPerformanceStats(serverSession);
          break;
        case 'q':
          _logger.info('Stopping web development server...');
          await serverSession.stop();
          await logSubscription.cancel();
          await keyboardSubscription.cancel();
          stdin.echoMode = true;
          stdin.lineMode = true;
          _logger.info('Web development server stopped');
          return;
      }
    });

    // Wait for server to end
    await serverSession.waitForExit();

    // Cleanup
    await logSubscription.cancel();
    await keyboardSubscription.cancel();
    stdin.echoMode = true;
    stdin.lineMode = true;
  }

  Future<void> _buildWeb(ArgResults results) async {
    final release = results['release'] as bool;
    final profile = results['profile'] as bool;
    final pwa = results['pwa'] as bool;
    final wasm = results['wasm'] as bool;
    final treeshakeIcons = results['tree-shake-icons'] as bool;
    final sourceMaps = results['source-maps'] as bool;
    final client = results['client'] as String?;
    final output = results['output'] as String;
    final verbose = results['verbose'] as bool;

    // Handle multi-client requirement
    if (_configService.multiClient && client == null) {
      CliUtils.printError('Multi-client mode requires --client parameter');
      CliUtils.printInfo(
          'Available clients: ${_configService.clients.join(', ')}');
      exit(1);
    }

    String buildMode = 'debug';
    if (release) {
      buildMode = 'release';
    } else if (profile) {
      buildMode = 'profile';
    }

    _logger.info('Building Flutter web app...');
    _logger.info('Build mode: $buildMode');
    _logger.info('Output directory: $output');
    if (client != null) _logger.info('Client: $client');
    if (pwa) _logger.info('PWA features enabled');
    if (wasm) _logger.info('WebAssembly compilation enabled');

    final success = await _webUseCase.buildWeb(
      buildMode: buildMode,
      client: client,
      outputDir: output,
      enablePWA: pwa,
      enableWasm: wasm,
      treeshakeIcons: treeshakeIcons,
      sourceMaps: sourceMaps,
      verbose: verbose,
    );

    if (success) {
      _logger.info('Web build completed successfully!');
      _logger.info('Output location: $output');

      // Show build analysis
      await _analyzeBuildOutput(output);
    } else {
      _logger.error('Web build failed');
      exit(1);
    }
  }

  Future<void> _deployWeb(ArgResults results) async {
    final output = results['output'] as String;
    final client = results['client'] as String?;

    if (!Directory(output).existsSync()) {
      CliUtils.printError('Build output not found: $output');
      CliUtils.printInfo('Run: flow web build --release');
      exit(1);
    }

    _logger.info('Preparing web deployment...');

    // Show deployment options
    final platforms = [
      'Firebase Hosting',
      'Netlify',
      'Vercel',
      'GitHub Pages',
      'AWS S3',
      'Custom Server (FTP/SFTP)',
      'Manual (Copy files)'
    ];

    final selectionIndex = Select(
      prompt: 'Select deployment platform:',
      options: platforms,
    ).interact();

    final platform =
        platforms[selectionIndex].toLowerCase().replaceAll(' ', '_');

    await _deployToPlatform(platform, output, client);
  }

  Future<void> _analyzeWeb(ArgResults results) async {
    final output = results['output'] as String;

    _logger.info('Analyzing web build...');

    if (!Directory(output).existsSync()) {
      _logger.warning('Build output not found. Building first...');
      await _buildWeb(results);
    }

    final analysis = await _webUseCase.analyzeWebBuild(output);
    _printWebAnalysis(analysis);
  }

  Future<void> _configurePWA(ArgResults results) async {
    _logger.info('Configuring Progressive Web App (PWA) features...');

    final pwaConfig = await _webUseCase.generatePWAConfig();

    if (pwaConfig != null) {
      _logger.info('PWA configuration generated successfully!');
      _logger.info('Files created:');
      _logger.info('  - web/manifest.json');
      _logger.info('  - web/sw.js (Service Worker)');
      _logger.info('  - web/icons/ (PWA icons)');
    } else {
      _logger.error('Failed to generate PWA configuration');
    }
  }

  Future<void> _optimizeWeb(ArgResults results) async {
    final output = results['output'] as String;

    _logger.info('Optimizing web build...');

    if (!Directory(output).existsSync()) {
      CliUtils.printError('Build output not found: $output');
      CliUtils.printInfo('Run: flow web build --release');
      exit(1);
    }

    final optimizations = await _webUseCase.optimizeWebBuild(output);

    _logger.info('Web optimization completed!');
    _logger.info('Optimizations applied:');
    for (final optimization in optimizations) {
      _logger.info('  ✓ $optimization');
    }
  }

  void _printWebServerInstructions(String hostname, int port) {
    _logger.info('\n${CliUtils.formatTitle('Flutter Web Development Server')}');
    CliUtils.printSeparator();
    _logger.info('🌐 Server running at: http://$hostname:$port');
    CliUtils.printSeparator();
    _logger.info(CliUtils.formatSubtitle('Commands:'));
    _logger.info('  r  - Hot reload');
    _logger.info('  R  - Hot restart');
    _logger.info('  o  - Open in browser');
    _logger.info('  h  - Show this help');
    _logger.info('  c  - Clear console');
    _logger.info('  l  - Show logs');
    _logger.info('  p  - Performance stats');
    _logger.info('  q  - Quit server');
    CliUtils.printSeparator();
    _logger.info('');
  }

  void _printWebLogEntry(WebLogEntry logEntry, bool verbose) {
    final timestamp = verbose
        ? '[${logEntry.timestamp.toIso8601String().substring(11, 23)}] '
        : '';

    final levelIcon = _getWebLogLevelIcon(logEntry.level);
    final formattedMessage = '$timestamp$levelIcon ${logEntry.message}';

    switch (logEntry.level.toLowerCase()) {
      case 'error':
        _logger.error('\x1b[31m$formattedMessage\x1b[0m');
        break;
      case 'warning':
        _logger.warning('\x1b[33m$formattedMessage\x1b[0m');
        break;
      case 'info':
        _logger.info('\x1b[34m$formattedMessage\x1b[0m');
        break;
      case 'debug':
        _logger.debug('\x1b[90m$formattedMessage\x1b[0m');
        break;
      default:
        _logger.info(formattedMessage);
    }
  }

  String _getWebLogLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return '❌';
      case 'warning':
        return '⚠️';
      case 'info':
        return '🌐';
      case 'debug':
        return '🔍';
      default:
        return '📝';
    }
  }

  Future<void> _performHotReload(WebServerSession session) async {
    CliUtils.clearLine();
    stdout.write('⚡ Reloading web app...');

    final stopwatch = Stopwatch()..start();
    final success = await _webUseCase.performWebHotReload(session);
    stopwatch.stop();

    CliUtils.clearLine();

    if (success) {
      _logger.info(
          '⚡ Web reload completed in ${stopwatch.elapsedMilliseconds}ms');
    } else {
      _logger.error('❌ Web reload failed');
    }
  }

  Future<void> _performHotRestart(WebServerSession session) async {
    CliUtils.clearLine();
    stdout.write('🔄 Restarting web app...');

    final stopwatch = Stopwatch()..start();
    final success = await _webUseCase.performWebHotRestart(session);
    stopwatch.stop();

    CliUtils.clearLine();

    if (success) {
      _logger.info(
          '🔄 Web restart completed in ${stopwatch.elapsedMilliseconds}ms');
    } else {
      _logger.error('❌ Web restart failed');
    }
  }

  Future<void> _openBrowser(String hostname, int port) async {
    try {
      final url = 'http://$hostname:$port';

      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', [url], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }

      _logger.info('Browser opened: $url');
    } catch (e) {
      _logger.error('Failed to open browser: $e');
    }
  }

  void _clearConsole() {
    if (Platform.isWindows) {
      Process.runSync('cls', [], runInShell: true);
    } else {
      Process.runSync('clear', []);
    }
    _printWebServerInstructions('localhost', 3000);
  }

  Future<void> _showWebLogs(WebServerSession session) async {
    _logger.info('📊 Web Server Logs:');
    // Implementation would show recent logs
  }

  Future<void> _showPerformanceStats(WebServerSession session) async {
    final stats = await _webUseCase.getPerformanceStats(session);

    _logger.info('\n${CliUtils.formatTitle('Performance Statistics')}');
    CliUtils.printSeparator();
    _logger.info('Uptime: ${stats['uptime']}');
    _logger.info('Requests served: ${stats['requests']}');
    _logger.info('Build time: ${stats['buildTime']}ms');
    _logger.info('Bundle size: ${stats['bundleSize']}');
    CliUtils.printSeparator();
    _logger.info('');
  }

  Future<void> _analyzeBuildOutput(String outputDir) async {
    final analysis = await _webUseCase.analyzeWebBuild(outputDir);
    _printWebAnalysis(analysis);
  }

  void _printWebAnalysis(Map<String, dynamic> analysis) {
    _logger.info('\n${CliUtils.formatTitle('Web Build Analysis')}');
    CliUtils.printSeparator();

    final bundleSize = analysis['bundleSize'] as String? ?? 'Unknown';
    final assetCount = analysis['assetCount'] as int? ?? 0;
    final loadTime = analysis['estimatedLoadTime'] as String? ?? 'Unknown';
    final recommendations = analysis['recommendations'] as List<String>? ?? [];

    _logger.info('📦 Bundle size: $bundleSize');
    _logger.info('📄 Asset count: $assetCount');
    _logger.info('⚡ Estimated load time: $loadTime');

    if (recommendations.isNotEmpty) {
      _logger.info('\n${CliUtils.formatSubtitle('Optimization Recommendations:')}');
      for (final rec in recommendations) {
        CliUtils.printInfo(rec);
      }
    }

    CliUtils.printSeparator();
    _logger.info('');
  }

  Future<void> _deployToPlatform(
      String platform, String output, String? client) async {
    switch (platform) {
      case 'firebase_hosting':
        await _deployToFirebase(output, client);
        break;
      case 'netlify':
        await _deployToNetlify(output, client);
        break;
      case 'vercel':
        await _deployToVercel(output, client);
        break;
      case 'github_pages':
        await _deployToGitHubPages(output, client);
        break;
      case 'aws_s3':
        await _deployToAWS(output, client);
        break;
      case 'custom_server_(ftp/sftp)':
        await _deployToCustomServer(output, client);
        break;
      case 'manual_(copy_files)':
        await _showManualDeployment(output, client);
        break;
    }
  }

  Future<void> _deployToFirebase(String output, String? client) async {
    _logger.info('🔥 Deploying to Firebase Hosting...');

    final success = await _webUseCase.deployToFirebase(output, client);

    if (success) {
      _logger.info('🔥 Successfully deployed to Firebase Hosting!');
    } else {
      _logger.error('Firebase deployment failed');
    }
  }

  Future<void> _deployToNetlify(String output, String? client) async {
    _logger.info('🌐 Deploying to Netlify...');

    final success = await _webUseCase.deployToNetlify(output, client);

    if (success) {
      _logger.info('🌐 Successfully deployed to Netlify!');
    } else {
      _logger.error('Netlify deployment failed');
    }
  }

  Future<void> _deployToVercel(String output, String? client) async {
    _logger.info('▲ Deploying to Vercel...');

    final success = await _webUseCase.deployToVercel(output, client);

    if (success) {
      _logger.info('▲ Successfully deployed to Vercel!');
    } else {
      _logger.error('Vercel deployment failed');
    }
  }

  Future<void> _deployToGitHubPages(String output, String? client) async {
    _logger.info('📄 Deploying to GitHub Pages...');

    final success = await _webUseCase.deployToGitHubPages(output, client);

    if (success) {
      _logger.info('📄 Successfully deployed to GitHub Pages!');
    } else {
      _logger.error('GitHub Pages deployment failed');
    }
  }

  Future<void> _deployToAWS(String output, String? client) async {
    _logger.info('☁️ Deploying to AWS S3...');

    final success = await _webUseCase.deployToAWS(output, client);

    if (success) {
      _logger.info('☁️ Successfully deployed to AWS S3!');
    } else {
      _logger.error('AWS S3 deployment failed');
    }
  }

  Future<void> _deployToCustomServer(String output, String? client) async {
    _logger.info('🖥️ Deploying to custom server...');

    final success = await _webUseCase.deployToCustomServer(output, client);

    if (success) {
      _logger.info('🖥️ Successfully deployed to custom server!');
    } else {
      _logger.error('Custom server deployment failed');
    }
  }

  Future<void> _showManualDeployment(String output, String? client) async {
    _logger.info('\n${CliUtils.formatTitle('Manual Deployment Instructions')}');
    CliUtils.printSeparator();
    _logger.info('Build output location: $output');
    _logger.info('');
    _logger.info(CliUtils.formatSubtitle('Deploy to any web hosting:'));
    _logger.info('1. Copy all files from: $output');
    _logger.info('2. Upload to your web server\'s public directory');
    _logger.info('3. Ensure your server supports SPA routing (optional)');
    _logger.info('4. Configure HTTPS (recommended)');
    _logger.info('');
    _logger.info(CliUtils.formatSubtitle('Important files:'));
    _logger.info('  • index.html - Main entry point');
    _logger.info('  • main.dart.js - Flutter web engine');
    _logger.info('  • assets/ - App assets and resources');
    _logger.info('  • manifest.json - PWA configuration (if enabled)');
    CliUtils.printSeparator();
  }

  void _showHelp(ArgParser parser) {
    _logger.info('''
${CliUtils.formatTitle('Flow CLI Web Development')}

${_localization.translate('commands.web')}

${CliUtils.formatSubtitle('Usage:')}
  flow web <command> [options]

${CliUtils.formatSubtitle('Commands:')}
  serve      Start development server
  build      Build web app
  deploy     Deploy web app
  analyze    Analyze web build
  pwa        Configure PWA features
  optimize   Optimize web build

${CliUtils.formatSubtitle('Options:')}
${parser.usage}

${CliUtils.formatSubtitle('Examples:')}
  flow web serve
  flow web serve --port 8080 --hostname localhost
  flow web build --release --pwa
  flow web build --client client1 --wasm
  flow web deploy --output ./build/web
  flow web analyze --output ./build/web
  flow web pwa
  flow web optimize --output ./build/web
''');
  }
}
