// Unit tests for lib/services/shake_service.dart's headless fake.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/services/shake_service.dart';

void main() {
  group('MockShakeService', () {
    test('does not fire until started', () {
      final service = MockShakeService();
      var count = 0;
      service.onShake.listen((_) => count++);

      service.fire();

      expect(count, 0);
      service.dispose();
    });

    test('fires an event per call while running', () async {
      final service = MockShakeService();
      final events = <void>[];
      service.onShake.listen(events.add);
      service.start();

      service.fire();
      service.fire();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      service.dispose();
    });

    test('stop() silences further shakes', () async {
      final service = MockShakeService();
      var count = 0;
      service.onShake.listen((_) => count++);
      service.start();
      service.stop();

      service.fire();
      await Future<void>.delayed(Duration.zero);

      expect(count, 0);
      service.dispose();
    });
  });
}
