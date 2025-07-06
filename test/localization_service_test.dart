import 'package:test/test.dart';
import 'package:flow_cli/shared/services/localization_service.dart';

void main() {
  group('LocalizationService', () {
    late LocalizationService localizationService;

    setUp(() {
      localizationService = LocalizationService.instance;
    });

    test('should initialize with English by default', () async {
      await localizationService.initialize('en');

      expect(localizationService.currentLanguage, equals('en'));
      expect(localizationService.translate('general.yes'), equals('Yes'));
    });

    test('should initialize with Spanish', () async {
      await localizationService.initialize('es');

      expect(localizationService.currentLanguage, equals('es'));
      expect(localizationService.translate('general.yes'), equals('Sí'));
    });

    test('should return key if translation not found', () async {
      await localizationService.initialize('en');

      expect(localizationService.translate('nonexistent.key'),
          equals('nonexistent.key'));
    });

    test('should handle help translations', () async {
      await localizationService.initialize('en');

      expect(localizationService.translate('help.description'),
          contains('comprehensive Flutter CLI tool'));

      await localizationService.initialize('es');

      expect(localizationService.translate('help.description'),
          contains('herramienta CLI integral de Flutter'));
    });

    test('should handle command translations', () async {
      await localizationService.initialize('en');

      expect(localizationService.translate('commands.setup'),
          contains('Initialize and configure'));

      await localizationService.initialize('es');

      expect(localizationService.translate('commands.setup'),
          contains('Inicializar y configurar'));
    });
  });
}
