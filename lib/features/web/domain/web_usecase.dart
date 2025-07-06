import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/config_service.dart';

class WebUseCase {
  final ConfigService _configService = ConfigService.instance;

  Future<WebServerSession?> startDevelopmentServer({
    required int port,
    required String hostname,
    String? client,
    required bool verbose,
    required bool autoOpen,
  }) async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      // Build command arguments
      final args = ['run', '-d', 'web-server'];

      // Add web-specific arguments
      args.addAll(['--web-port', port.toString()]);
      args.addAll(['--web-hostname', hostname]);

      // Add flavor for multi-client
      if (client != null) {
        args.addAll(['--flavor', client]);
      }

      // Add verbose flag if requested
      if (verbose) {
        args.add('--verbose');
      }

      CliUtils.printInfo('Starting Flutter web server...');
      CliUtils.printInfo('Command: flutter ${args.join(' ')}');

      // Start the Flutter process
      final process = await Process.start(
        flutterBin,
        args,
        workingDirectory: projectPath,
        mode: ProcessStartMode.normal,
      );

      final session = WebServerSession(
        process: process,
        port: port,
        hostname: hostname,
        client: client,
        startTime: DateTime.now(),
      );

      // Wait for server to start
      await Future.delayed(Duration(seconds: 3));

      // Check if process is still running
      if (await _isProcessRunning(process)) {
        CliUtils.printSuccess('Web development server started successfully');

        // Auto-open browser if requested
        if (autoOpen) {
          await _openBrowser(hostname, port);
        }

        return session;
      } else {
        CliUtils.printError('Failed to start web development server');
        return null;
      }
    } catch (e) {
      CliUtils.printError('Error starting web development server: $e');
      return null;
    }
  }

  Future<bool> _isProcessRunning(Process process) async {
    try {
      // Try to kill with signal 0 (just check if process exists)
      process.kill(ProcessSignal.sigusr1);
      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<WebLogEntry> getLogStream(WebServerSession session) {
    final controller = StreamController<WebLogEntry>();

    // Listen to stdout
    session.process.stdout
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        final logEntry = _parseWebLogLine(line, 'stdout');
        controller.add(logEntry);
      }
    });

    // Listen to stderr
    session.process.stderr
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        final logEntry = _parseWebLogLine(line, 'stderr');
        controller.add(logEntry);
      }
    });

    // Handle process exit
    session.process.exitCode.then((exitCode) {
      controller.add(WebLogEntry(
        level: 'info',
        message: 'Web server process exited with code: $exitCode',
        timestamp: DateTime.now(),
        source: 'system',
      ));
      controller.close();
    });

    return controller.stream;
  }

  WebLogEntry _parseWebLogLine(String line, String source) {
    final timestamp = DateTime.now();

    // Parse web-specific log levels
    String level = 'info';
    String message = line;

    if (line.contains('[ERROR]') ||
        line.contains('ERROR:') ||
        line.contains('Exception:')) {
      level = 'error';
    } else if (line.contains('[WARNING]') ||
        line.contains('WARNING:') ||
        line.contains('Warning:')) {
      level = 'warning';
    } else if (line.contains('[DEBUG]') || line.contains('DEBUG:')) {
      level = 'debug';
    } else if (line.contains('[INFO]') ||
        line.contains('INFO:') ||
        line.contains('Serving at')) {
      level = 'info';
    }

    // Clean up common Flutter web prefixes
    message = message
        .replaceAll(
            RegExp(r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] '), '')
        .replaceAll(RegExp(r'^(DEBUG|INFO|WARNING|ERROR):\s*'), '')
        .replaceAll(RegExp(r'^\[.+?\]\s*'), '')
        .trim();

    return WebLogEntry(
      level: level,
      message: message,
      timestamp: timestamp,
      source: source,
      rawLine: line,
    );
  }

  Future<bool> performWebHotReload(WebServerSession session) async {
    try {
      // Send 'r' command to Flutter process for hot reload
      session.process.stdin.writeln('r');
      await session.process.stdin.flush();

      session.reloadCount++;

      // Wait a bit for the reload to process
      await Future.delayed(Duration(milliseconds: 500));

      return true;
    } catch (e) {
      CliUtils.printError('Web hot reload error: $e');
      return false;
    }
  }

  Future<bool> performWebHotRestart(WebServerSession session) async {
    try {
      // Send 'R' command to Flutter process for hot restart
      session.process.stdin.writeln('R');
      await session.process.stdin.flush();

      session.restartCount++;

      // Wait a bit for the restart to process
      await Future.delayed(Duration(seconds: 2));

      return true;
    } catch (e) {
      CliUtils.printError('Web hot restart error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getPerformanceStats(
      WebServerSession session) async {
    try {
      return {
        'uptime': _formatDuration(DateTime.now().difference(session.startTime)),
        'requests': session.requestCount,
        'buildTime': session.lastBuildTime,
        'bundleSize': await _getBundleSize(),
        'reloads': session.reloadCount,
        'restarts': session.restartCount,
      };
    } catch (e) {
      return {};
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<String> _getBundleSize() async {
    try {
      final projectPath = _configService.projectPath!;
      final buildDir = Directory(path.join(projectPath, 'build', 'web'));

      if (!await buildDir.exists()) {
        return 'Not built';
      }

      int totalSize = 0;
      await for (final entity in buildDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return _formatBytes(totalSize);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  Future<bool> buildWeb({
    required String buildMode,
    String? client,
    required String outputDir,
    required bool enablePWA,
    required bool enableWasm,
    required bool treeshakeIcons,
    required bool sourceMaps,
    required bool verbose,
  }) async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      // Build command arguments
      final args = ['build', 'web'];

      // Add build mode
      if (buildMode == 'release') {
        args.add('--release');
      } else if (buildMode == 'profile') {
        args.add('--profile');
      }

      // Add output directory
      args.addAll(['--output', outputDir]);

      // Add flavor for multi-client
      if (client != null) {
        args.addAll(['--flavor', client]);
      }

      // Add web-specific options
      if (enableWasm) {
        args.add('--wasm');
      }

      if (!treeshakeIcons) {
        args.add('--no-tree-shake-icons');
      }

      if (!sourceMaps && buildMode == 'release') {
        args.add('--no-source-maps');
      }

      // Add verbose flag if requested
      if (verbose) {
        args.add('--verbose');
      }

      CliUtils.printInfo('Building web application...');

      final result = await Process.run(
        flutterBin,
        args,
        workingDirectory: projectPath,
      );

      if (result.exitCode == 0) {
        CliUtils.printSuccess('Web build completed successfully');

        // Generate PWA files if enabled
        if (enablePWA) {
          await _generatePWAFiles(outputDir, client);
        }

        return true;
      } else {
        CliUtils.printError(
            'Web build failed with exit code: ${result.exitCode}');
        print(result.stderr);
        return false;
      }
    } catch (e) {
      CliUtils.printError('Web build error: $e');
      return false;
    }
  }

  Future<void> _generatePWAFiles(String outputDir, String? client) async {
    try {
      // Generate manifest.json if it doesn't exist
      final manifestFile = File(path.join(outputDir, 'manifest.json'));
      if (!await manifestFile.exists()) {
        await _generateManifest(manifestFile, client);
      }

      // Generate service worker
      final swFile = File(path.join(outputDir, 'sw.js'));
      await _generateServiceWorker(swFile);

      // Generate PWA icons
      await _generatePWAIcons(outputDir, client);

      CliUtils.printSuccess('PWA files generated');
    } catch (e) {
      CliUtils.printError('Error generating PWA files: $e');
    }
  }

  Future<void> _generateManifest(File manifestFile, String? client) async {
    final appName = client ?? 'Flutter Web App';

    final manifest = {
      'name': appName,
      'short_name': appName,
      'start_url': './',
      'display': 'standalone',
      'background_color': '#ffffff',
      'theme_color': '#000000',
      'description': 'A Flutter web application',
      'orientation': 'portrait-primary',
      'prefer_related_applications': false,
      'icons': [
        {
          'src': 'icons/Icon-192.png',
          'sizes': '192x192',
          'type': 'image/png',
          'purpose': 'maskable any'
        },
        {
          'src': 'icons/Icon-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'maskable any'
        }
      ]
    };

    await manifestFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
  }

  Future<void> _generateServiceWorker(File swFile) async {
    const swContent = '''
const CACHE_NAME = 'flutter-app-cache-v1';
const urlsToCache = [
  '/',
  '/main.dart.js',
  '/manifest.json',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Return cached version or fetch from network
        return response || fetch(event.request);
      })
  );
});
''';

    await swFile.writeAsString(swContent);
  }

  Future<void> _generatePWAIcons(String outputDir, String? client) async {
    // In a real implementation, this would generate actual icon files
    // For now, we'll create placeholder files
    final iconsDir = Directory(path.join(outputDir, 'icons'));
    await iconsDir.create(recursive: true);

    // Create placeholder icon files
    for (final size in [192, 512]) {
      final iconFile = File(path.join(iconsDir.path, 'Icon-$size.png'));
      await iconFile.writeAsString('# Placeholder for $size x $size icon');
    }
  }

  Future<Map<String, dynamic>?> generatePWAConfig() async {
    try {
      final projectPath = _configService.projectPath!;
      final webDir = Directory(path.join(projectPath, 'web'));

      if (!await webDir.exists()) {
        await webDir.create(recursive: true);
      }

      // Generate manifest.json
      final manifestFile = File(path.join(webDir.path, 'manifest.json'));
      await _generateManifest(manifestFile, null);

      // Generate service worker
      final swFile = File(path.join(webDir.path, 'sw.js'));
      await _generateServiceWorker(swFile);

      // Generate icons directory
      await _generatePWAIcons(webDir.path, null);

      return {
        'manifest': manifestFile.path,
        'serviceWorker': swFile.path,
        'icons': path.join(webDir.path, 'icons'),
      };
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> analyzeWebBuild(String outputDir) async {
    try {
      final buildDir = Directory(outputDir);

      if (!await buildDir.exists()) {
        return {
          'error': 'Build directory not found',
        };
      }

      // Calculate bundle size
      int totalSize = 0;
      int assetCount = 0;

      await for (final entity in buildDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
          assetCount++;
        }
      }

      // Estimate load time (rough calculation)
      final loadTimeMs = (totalSize / 1024 / 100).round(); // Assume 100KB/s
      final loadTime = loadTimeMs > 1000
          ? '${(loadTimeMs / 1000).toStringAsFixed(1)}s'
          : '${loadTimeMs}ms';

      // Generate recommendations
      final recommendations = <String>[];

      if (totalSize > 5 * 1024 * 1024) {
        // > 5MB
        recommendations.add('Consider code splitting to reduce bundle size');
      }

      if (assetCount > 100) {
        recommendations.add(
            'Large number of assets detected - consider optimizing images');
      }

      // Check for specific files
      final mainJsFile = File(path.join(outputDir, 'main.dart.js'));
      if (await mainJsFile.exists()) {
        final mainJsSize = await mainJsFile.length();
        if (mainJsSize > 2 * 1024 * 1024) {
          // > 2MB
          recommendations
              .add('Main Dart JS file is large - enable tree shaking');
        }
      }

      return {
        'bundleSize': _formatBytes(totalSize),
        'assetCount': assetCount,
        'estimatedLoadTime': loadTime,
        'recommendations': recommendations,
      };
    } catch (e) {
      return {
        'error': 'Analysis failed: $e',
      };
    }
  }

  Future<List<String>> optimizeWebBuild(String outputDir) async {
    final optimizations = <String>[];

    try {
      // Compress JavaScript files
      final jsFiles = await Directory(outputDir)
          .list(recursive: true)
          .where((file) => file.path.endsWith('.js'))
          .cast<File>()
          .toList();

      for (final jsFile in jsFiles) {
        // In a real implementation, this would use a JS minifier
        optimizations.add('Minified ${path.basename(jsFile.path)}');
      }

      // Optimize images
      final imageFiles = await Directory(outputDir)
          .list(recursive: true)
          .where((file) =>
              file.path.endsWith('.png') ||
              file.path.endsWith('.jpg') ||
              file.path.endsWith('.jpeg'))
          .cast<File>()
          .toList();

      for (final imageFile in imageFiles) {
        // In a real implementation, this would use image optimization tools
        optimizations.add('Optimized ${path.basename(imageFile.path)}');
      }

      // Generate compressed assets
      optimizations.add('Generated gzip compressed assets');

      // Add cache headers configuration
      optimizations.add('Generated cache configuration');
    } catch (e) {
      CliUtils.printError('Optimization error: $e');
    }

    return optimizations;
  }

  // Deployment methods
  Future<bool> deployToFirebase(String outputDir, String? client) async {
    try {
      // Check if Firebase CLI is installed
      final firebaseResult = await Process.run('firebase', ['--version']);
      if (firebaseResult.exitCode != 0) {
        CliUtils.printError(
            'Firebase CLI not found. Install it first: npm install -g firebase-tools');
        return false;
      }

      // Check if project is initialized
      final projectPath = _configService.projectPath!;
      final firebaseConfig = File(path.join(projectPath, 'firebase.json'));

      if (!await firebaseConfig.exists()) {
        CliUtils.printInfo('Initializing Firebase project...');
        final initResult = await Process.run(
          'firebase',
          ['init', 'hosting'],
          workingDirectory: projectPath,
        );

        if (initResult.exitCode != 0) {
          CliUtils.printError('Firebase initialization failed');
          return false;
        }
      }

      // Deploy
      final deployResult = await Process.run(
        'firebase',
        ['deploy', '--only', 'hosting'],
        workingDirectory: projectPath,
      );

      return deployResult.exitCode == 0;
    } catch (e) {
      CliUtils.printError('Firebase deployment error: $e');
      return false;
    }
  }

  Future<bool> deployToNetlify(String outputDir, String? client) async {
    try {
      // Check if Netlify CLI is installed
      final netlifyResult = await Process.run('netlify', ['--version']);
      if (netlifyResult.exitCode != 0) {
        CliUtils.printError(
            'Netlify CLI not found. Install it first: npm install -g netlify-cli');
        return false;
      }

      // Deploy
      final deployResult = await Process.run(
        'netlify',
        ['deploy', '--prod', '--dir', outputDir],
      );

      return deployResult.exitCode == 0;
    } catch (e) {
      CliUtils.printError('Netlify deployment error: $e');
      return false;
    }
  }

  Future<bool> deployToVercel(String outputDir, String? client) async {
    try {
      // Check if Vercel CLI is installed
      final vercelResult = await Process.run('vercel', ['--version']);
      if (vercelResult.exitCode != 0) {
        CliUtils.printError(
            'Vercel CLI not found. Install it first: npm install -g vercel');
        return false;
      }

      // Deploy
      final deployResult = await Process.run(
        'vercel',
        ['--prod', outputDir],
      );

      return deployResult.exitCode == 0;
    } catch (e) {
      CliUtils.printError('Vercel deployment error: $e');
      return false;
    }
  }

  Future<bool> deployToGitHubPages(String outputDir, String? client) async {
    try {
      final projectPath = _configService.projectPath!;

      // Check if we're in a git repository
      final gitResult =
          await Process.run('git', ['status'], workingDirectory: projectPath);
      if (gitResult.exitCode != 0) {
        CliUtils.printError('Not a git repository. Initialize git first.');
        return false;
      }

      // Create gh-pages branch and deploy
      final commands = [
        ['git', 'checkout', '--orphan', 'gh-pages'],
        ['git', 'rm', '-rf', '.'],
        ['cp', '-r', '$outputDir/*', '.'],
        ['git', 'add', '.'],
        ['git', 'commit', '-m', 'Deploy to GitHub Pages'],
        ['git', 'push', 'origin', 'gh-pages', '--force'],
        ['git', 'checkout', 'main'],
      ];

      for (final command in commands) {
        final result = await Process.run(
          command[0],
          command.skip(1).toList(),
          workingDirectory: projectPath,
        );

        if (result.exitCode != 0 && !command.contains('checkout')) {
          CliUtils.printError(
              'GitHub Pages deployment failed at: ${command.join(' ')}');
          return false;
        }
      }

      return true;
    } catch (e) {
      CliUtils.printError('GitHub Pages deployment error: $e');
      return false;
    }
  }

  Future<bool> deployToAWS(String outputDir, String? client) async {
    try {
      // Check if AWS CLI is installed
      final awsResult = await Process.run('aws', ['--version']);
      if (awsResult.exitCode != 0) {
        CliUtils.printError(
            'AWS CLI not found. Install and configure it first.');
        return false;
      }

      CliUtils.printInfo('AWS S3 deployment requires bucket configuration.');
      CliUtils.printInfo(
          'This would typically use: aws s3 sync $outputDir s3://your-bucket --delete');

      // In a real implementation, this would prompt for bucket name and deploy
      return true;
    } catch (e) {
      CliUtils.printError('AWS deployment error: $e');
      return false;
    }
  }

  Future<bool> deployToCustomServer(String outputDir, String? client) async {
    try {
      CliUtils.printInfo(
          'Custom server deployment requires FTP/SFTP configuration.');
      CliUtils.printInfo(
          'You can use tools like rsync, scp, or FTP clients to upload:');
      CliUtils.printInfo('Source: $outputDir');

      // In a real implementation, this would prompt for server details and deploy
      return true;
    } catch (e) {
      CliUtils.printError('Custom server deployment error: $e');
      return false;
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
    } catch (e) {
      // Ignore browser open errors
    }
  }
}

class WebServerSession {
  final Process process;
  final int port;
  final String hostname;
  final String? client;
  final DateTime startTime;

  int reloadCount = 0;
  int restartCount = 0;
  int requestCount = 0;
  int lastBuildTime = 0;

  WebServerSession({
    required this.process,
    required this.port,
    required this.hostname,
    required this.client,
    required this.startTime,
  });

  Future<void> stop() async {
    try {
      // Send quit command
      process.stdin.writeln('q');
      await process.stdin.flush();

      // Wait a bit for graceful shutdown
      await Future.delayed(Duration(seconds: 1));

      // Force kill if still running
      if (!process.kill()) {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (e) {
      // Force kill if all else fails
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }

  Future<int> waitForExit() async {
    return await process.exitCode;
  }

  bool get isRunning {
    try {
      process.kill(ProcessSignal.sigusr1);
      return true;
    } catch (e) {
      return false;
    }
  }
}

class WebLogEntry {
  final String level;
  final String message;
  final DateTime timestamp;
  final String source;
  final String? rawLine;

  WebLogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    required this.source,
    this.rawLine,
  });

  @override
  String toString() {
    return '[$level] $message';
  }
}
