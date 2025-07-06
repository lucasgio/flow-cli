import 'package:logging/logging.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  static AppLogger get instance => _instance;

  late final Logger _logger;

  AppLogger._internal() {
    _logger = Logger('FlowCLI');
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
    });
  }

  void info(String message) => _logger.info(message);
  void warning(String message) => _logger.warning(message);
  void error(String message) => _logger.severe(message);
  void debug(String message) => _logger.fine(message);
} 