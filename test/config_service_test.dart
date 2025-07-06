import 'package:test/test.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/shared/models/config_model.dart';

void main() {
  group('ConfigService', () {
    late ConfigService configService;

    setUp(() async {
      configService = ConfigService.instance;
      await configService.initialize();
    });

    test('should create default config', () {
      final config = ConfigModel.defaultConfig();

      expect(config.language, equals('en'));
      expect(config.multiClient, equals(false));
      expect(config.clients, isEmpty);
      expect(config.flutterPath, isNull);
      expect(config.projectPath, isNull);
    });

    test('should set and get language', () {
      configService.setLanguage('es');
      expect(configService.language, equals('es'));
    });

    test('should set and get multi-client mode', () {
      configService.setMultiClient(true);
      expect(configService.multiClient, equals(true));
    });

    test('should add and remove clients', () {
      configService.addClient('client1');
      expect(configService.clients, contains('client1'));

      configService.addClient('client2');
      expect(configService.clients.length, equals(2));

      configService.removeClient('client1');
      expect(configService.clients, isNot(contains('client1')));
      expect(configService.clients, contains('client2'));
    });

    test('should check if configured', () {
      // Reset to default state for this test
      configService.resetToDefault();

      expect(configService.isConfigured, equals(false));

      configService.setFlutterPath('/test/flutter');
      configService.setProjectPath('/test/project');

      expect(configService.isConfigured, equals(true));
    });
  });
}
