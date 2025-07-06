import 'package:flow_cli/core/constants/app_constants.dart';

class ConfigModel {
  final String language;
  final String? flutterPath;
  final String? projectPath;
  final bool multiClient;
  final String? currentClient;
  final List<String> clients;
  final Map<String, dynamic> customSettings;

  const ConfigModel({
    required this.language,
    this.flutterPath,
    this.projectPath,
    required this.multiClient,
    this.currentClient,
    required this.clients,
    required this.customSettings,
  });

  factory ConfigModel.defaultConfig() {
    return const ConfigModel(
      language: AppConstants.defaultLanguage,
      multiClient: false,
      clients: [],
      customSettings: {},
    );
  }

  factory ConfigModel.fromJson(Map<String, dynamic> json) {
    return ConfigModel(
      language: json['language'] as String? ?? AppConstants.defaultLanguage,
      flutterPath: json['flutterPath'] as String?,
      projectPath: json['projectPath'] as String?,
      multiClient: json['multiClient'] as bool? ?? false,
      currentClient: json['currentClient'] as String?,
      clients: (json['clients'] as List<dynamic>?)?.cast<String>() ?? [],
      customSettings: json['customSettings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'flutterPath': flutterPath,
      'projectPath': projectPath,
      'multiClient': multiClient,
      'currentClient': currentClient,
      'clients': clients,
      'customSettings': customSettings,
    };
  }

  ConfigModel copyWith({
    String? language,
    String? flutterPath,
    String? projectPath,
    bool? multiClient,
    String? currentClient,
    List<String>? clients,
    Map<String, dynamic>? customSettings,
  }) {
    return ConfigModel(
      language: language ?? this.language,
      flutterPath: flutterPath ?? this.flutterPath,
      projectPath: projectPath ?? this.projectPath,
      multiClient: multiClient ?? this.multiClient,
      currentClient: currentClient ?? this.currentClient,
      clients: clients ?? this.clients,
      customSettings: customSettings ?? this.customSettings,
    );
  }

  @override
  String toString() {
    return 'ConfigModel(language: $language, flutterPath: $flutterPath, projectPath: $projectPath, multiClient: $multiClient, currentClient: $currentClient, clients: $clients)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ConfigModel &&
        other.language == language &&
        other.flutterPath == flutterPath &&
        other.projectPath == projectPath &&
        other.multiClient == multiClient &&
        other.currentClient == currentClient &&
        _listEquals(other.clients, clients) &&
        _mapEquals(other.customSettings, customSettings);
  }

  @override
  int get hashCode {
    return language.hashCode ^
        flutterPath.hashCode ^
        projectPath.hashCode ^
        multiClient.hashCode ^
        currentClient.hashCode ^
        clients.hashCode ^
        customSettings.hashCode;
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
