import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/vision/obstacle_detector.dart';

void main() {
  group('MockObstacleDetector', () {
    test('emits detections that get steadily closer while running', () async {
      final detector = MockObstacleDetector(
        tickInterval: const Duration(milliseconds: 5),
        step: 0.5,
      );
      final seen = <double>[];
      final sub = detector.detections.listen(
        (d) => seen.add(d.single.closeness),
      );

      await detector.start();
      await Future.delayed(const Duration(milliseconds: 30));
      await detector.dispose();
      await sub.cancel();

      expect(seen, isNotEmpty);
      expect(seen.first, lessThanOrEqualTo(seen.last));
      expect(seen.last, lessThanOrEqualTo(1.0));
    });

    test('stop halts further emissions', () async {
      final detector = MockObstacleDetector(
        tickInterval: const Duration(milliseconds: 5),
      );
      var count = 0;
      final sub = detector.detections.listen((_) => count++);

      await detector.start();
      await Future.delayed(const Duration(milliseconds: 20));
      await detector.stop();
      final afterStop = count;
      await Future.delayed(const Duration(milliseconds: 20));

      expect(count, afterStop);
      await sub.cancel();
      await detector.dispose();
    });
  });
}
