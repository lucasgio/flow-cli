import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flow_cli/core/constants/app_constants.dart';
import 'package:flow_cli/shared/models/config_model.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  static ConfigService get instance => _instance;

  ConfigService._internal();

  late ConfigModel _config;

  ConfigModel get config => _config;

  Future<void> initialize() async {
    await _loadConfig();
  }

  Future<void> _loadConfig() async {
    final configFile = await getConfigFile();

    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _config = ConfigModel.fromJson(json);
      } catch (e) {
        // If config file is corrupted, create a new one
        _config = ConfigModel.defaultConfig();
      }
    } else {
      _config = ConfigModel.defaultConfig();
    }
  }

  Future<void> saveConfig() async {
    final configFile = await getConfigFile();
    await configFile.parent.create(recursive: true);
    await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_config.toJson()));
  }

  Future<File> getConfigFile() async {
    final homeDir = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final configDir = Directory(path.join(homeDir, AppConstants.configDir));
    return File(path.join(configDir.path, AppConstants.configFile));
  }

  // Setters
  void setLanguage(String language) {
    _config = _config.copyWith(language: language);
  }

  void setFlutterPath(String flutterPath) {
    _config = _config.copyWith(flutterPath: flutterPath);
  }

  void setProjectPath(String projectPath) {
    _config = _config.copyWith(projectPath: projectPath);
  }

  void setMultiClient(bool multiClient) {
    _config = _config.copyWith(multiClient: multiClient);
  }

  void setCurrentClient(String? client) {
    _config = _config.copyWith(currentClient: client);
  }

  void addClient(String clientName) {
    final updatedClients = List<String>.from(_config.clients)..add(clientName);
    _config = _config.copyWith(clients: updatedClients);
  }

  void removeClient(String clientName) {
    final updatedClients = List<String>.from(_config.clients)
      ..remove(clientName);
    _config = _config.copyWith(clients: updatedClients);
  }

  // Getters
  String get language => _config.language;
  String? get flutterPath => _config.flutterPath;
  String? get projectPath => _config.projectPath;
  bool get multiClient => _config.multiClient;
  String? get currentClient => _config.currentClient;
  List<String> get clients => _config.clients;

  bool get isConfigured =>
      _config.flutterPath != null && _config.projectPath != null;

  // Testing helper
  void resetToDefault() {
    _config = ConfigModel.defaultConfig();
  }
}
