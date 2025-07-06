import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  static LocalizationService get instance => _instance;

  LocalizationService._internal();

  Map<String, String> _translations = {};
  String _currentLanguage = 'en';

  Future<void> initialize(String language) async {
    _currentLanguage = language;
    await _loadTranslations(language);
  }

  Future<void> _loadTranslations(String language) async {
    final translationsMap = {
      'en': _englishTranslations,
      'es': _spanishTranslations,
    };

    _translations = translationsMap[language] ?? _englishTranslations;
  }

  String translate(String key) {
    return _translations[key] ?? key;
  }

  String get currentLanguage => _currentLanguage;

  static const Map<String, String> _englishTranslations = {
    // Help
    'help.description':
        'A comprehensive Flutter CLI tool for project management, building, and deployment',
    'help.more_info':
        'For more information, visit: https://docs.flowstore.com/flow-cli',

    // Commands
    'commands.setup': 'Initialize and configure a new Flutter project',
    'commands.build': 'Build Flutter applications for Android and iOS',
    'commands.device': 'Manage and deploy to Android and iOS devices',
    'commands.analyze': 'Analyze and optimize Flutter applications',
    'commands.config': 'Configure Flutter SDK and project settings',
    'commands.hotreload': 'Start hot reload session with real-time logging',
    'commands.web': 'Web development server and deployment tools',

    // Setup
    'setup.welcome': 'Welcome to Flow CLI Setup!',
    'setup.multi_client': 'Will this application use multiple clients?',
    'setup.multi_client_guide': 'Multi-client setup guide',
    'setup.folder_structure': 'Please create the following folder structure:',
    'setup.branding_info': 'For each client, you need to provide:',
    'setup.complete': 'Setup completed successfully!',

    // Build
    'build.starting': 'Starting build process...',
    'build.success': 'Build completed successfully!',
    'build.failed': 'Build failed!',
    'build.platform_required': 'Platform is required (android/ios)',

    // Device
    'device.listing': 'Listing available devices...',
    'device.none_found': 'No devices found',
    'device.deployment_success': 'App deployed successfully!',

    // Config
    'config.flutter_path': 'Flutter SDK path',
    'config.project_path': 'Project path',
    'config.saved': 'Configuration saved!',
    'config.flutter_not_found': 'Flutter SDK not found at specified path',

    // Analyze
    'analyze.starting': 'Starting analysis...',
    'analyze.recommendations': 'Optimization recommendations:',
    'analyze.complete': 'Analysis completed!',

    // General
    'general.yes': 'Yes',
    'general.no': 'No',
    'general.cancel': 'Cancel',
    'general.continue': 'Continue',
    'general.exit': 'Exit',
  };

  static const Map<String, String> _spanishTranslations = {
    // Help
    'help.description':
        'Una herramienta CLI integral de Flutter para gestión de proyectos, construcción y despliegue',
    'help.more_info':
        'Para más información, visita: https://docs.flowstore.com/flow-cli',

    // Commands
    'commands.setup': 'Inicializar y configurar un nuevo proyecto Flutter',
    'commands.build': 'Construir aplicaciones Flutter para Android e iOS',
    'commands.device': 'Gestionar y desplegar en dispositivos Android e iOS',
    'commands.analyze': 'Analizar y optimizar aplicaciones Flutter',
    'commands.config': 'Configurar Flutter SDK y ajustes del proyecto',
    'commands.hotreload':
        'Iniciar sesión de hot reload con logs en tiempo real',
    'commands.web': 'Servidor de desarrollo web y herramientas de despliegue',

    // Setup
    'setup.welcome': '¡Bienvenido a la configuración de Flow CLI!',
    'setup.multi_client': '¿Esta aplicación usará múltiples clientes?',
    'setup.multi_client_guide': 'Guía de configuración multi-cliente',
    'setup.folder_structure':
        'Por favor crea la siguiente estructura de carpetas:',
    'setup.branding_info': 'Para cada cliente, necesitas proporcionar:',
    'setup.complete': '¡Configuración completada exitosamente!',

    // Build
    'build.starting': 'Iniciando proceso de construcción...',
    'build.success': '¡Construcción completada exitosamente!',
    'build.failed': '¡Falló la construcción!',
    'build.platform_required': 'La plataforma es requerida (android/ios)',

    // Device
    'device.listing': 'Listando dispositivos disponibles...',
    'device.none_found': 'No se encontraron dispositivos',
    'device.deployment_success': '¡App desplegada exitosamente!',

    // Config
    'config.flutter_path': 'Ruta del SDK de Flutter',
    'config.project_path': 'Ruta del proyecto',
    'config.saved': '¡Configuración guardada!',
    'config.flutter_not_found':
        'SDK de Flutter no encontrado en la ruta especificada',

    // Analyze
    'analyze.starting': 'Iniciando análisis...',
    'analyze.recommendations': 'Recomendaciones de optimización:',
    'analyze.complete': '¡Análisis completado!',

    // General
    'general.yes': 'Sí',
    'general.no': 'No',
    'general.cancel': 'Cancelar',
    'general.continue': 'Continuar',
    'general.exit': 'Salir',
  };
}
