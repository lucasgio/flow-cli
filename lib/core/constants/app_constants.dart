class AppConstants {
  static const String version = '1.0.0';
  static const String appName = 'Flow CLI';
  static const String description = 'A comprehensive Flutter CLI tool for project management';
  
  // Configuration
  static const String configDir = '.flow_cli';
  static const String configFile = 'config.json';
  static const String brandingScript = 'generate_branding.py';
  
  // URLs
  static const String repositoryUrl = 'https://github.com/Flowstore/flow-cli';
  static const String issuesUrl = 'https://github.com/Flowstore/flow-cli/issues';
  static const String documentationUrl = 'https://docs.flowstore.com/flow-cli';
  
  // Supported platforms
  static const List<String> supportedPlatforms = ['android', 'ios', 'web'];
  static const List<String> supportedLanguages = ['en', 'es'];
  
  // Default values
  static const String defaultLanguage = 'en';
  static const String defaultBuildMode = 'debug';
}