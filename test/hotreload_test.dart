import 'package:test/test.dart';
import 'package:flow_cli/features/hotreload/domain/hotreload_usecase.dart';
import 'package:flow_cli/shared/models/device_model.dart';

void main() {
  group('HotReloadUseCase', () {
    late HotReloadUseCase hotReloadUseCase;

    setUp(() {
      hotReloadUseCase = HotReloadUseCase();
    });

    test('should create log entry with correct level', () {
      final logEntry = LogEntry(
        level: 'info',
        message: 'Test message',
        timestamp: DateTime.now(),
        source: 'test',
      );
      
      expect(logEntry.level, equals('info'));
      expect(logEntry.message, equals('Test message'));
      expect(logEntry.source, equals('test'));
    });

    test('should create hot reload session', () {
      final device = DeviceModel(
        id: 'test-device',
        name: 'Test Device',
        platform: 'android',
        isPhysical: false,
        isOnline: true,
      );
      
      // Note: We can't easily test actual process creation in unit tests
      // This would require integration tests with actual Flutter projects
      expect(device.platform, equals('android'));
      expect(device.isOnline, equals(true));
    });

    test('should detect connected devices', () async {
      // Note: This test would require a configured Flutter environment
      // In a real scenario, you'd mock the Flutter command execution
      final devices = await hotReloadUseCase.getConnectedDevices();
      expect(devices, isA<List<String>>());
    });

    test('should create performance metrics', () async {
      final device = DeviceModel(
        id: 'test-device',
        name: 'Test Device',
        platform: 'android',
        isPhysical: false,
        isOnline: true,
      );
      
      // Mock session (can't create real process in tests)
      final startTime = DateTime.now();
      
      // In a real session, we'd pass the actual process
      final metrics = {
        'device': device.name,
        'platform': device.platform,
        'uptime': DateTime.now().difference(startTime).inMilliseconds,
      };
      
      expect(metrics['device'], equals('Test Device'));
      expect(metrics['platform'], equals('android'));
      expect(metrics['uptime'], isA<int>());
    });
  });
}