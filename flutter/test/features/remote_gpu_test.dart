import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/sidequest/remote_gpu.dart';

void main() {
  group('UnavailableRemoteGpuClient', () {
    test('reports itself unavailable', () {
      const client = UnavailableRemoteGpuClient();
      expect(client.available, isFalse);
    });

    test('refuses jobs rather than faking a remote call', () async {
      const client = UnavailableRemoteGpuClient();
      final result = await client.summarizeThread(['hi'], consent: true);

      expect(result.ok, isFalse);
      expect(result.summary, isNull);
      expect(result.error, isNotNull);
    });
  });
}
