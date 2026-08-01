import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/messaging/attachments.dart';
import 'package:echo/utils/relay.dart' show chunkChars;

import '../support/fakes.dart';

void main() {
  group('chunkCount', () {
    test('a single hop for anything that fits under the chunk size', () {
      expect(chunkCount(0), 1);
      expect(chunkCount(100), 1);
      expect(chunkCount(chunkChars), 1);
    });

    test('rounds up to the next whole chunk', () {
      expect(chunkCount(chunkChars + 1), 2);
      expect(chunkCount(chunkChars * 2), 2);
      expect(chunkCount(chunkChars * 2 + 1), 3);
    });

    test('honours a custom chunk size', () {
      expect(chunkCount(21, chunkSize: 10), 3);
    });
  });

  group('MockImageSource', () {
    test('picks a canned image by default from either source', () async {
      final source = MockImageSource();
      expect(await source.pickFromLibrary(), isNotNull);
      expect(await source.pickFromCamera(), isNotNull);
    });

    test('returns null once scripted to simulate backing out', () async {
      final source = MockImageSource()..next = null;
      expect(await source.pickFromLibrary(), isNull);
      expect(await source.pickFromCamera(), isNull);
    });

    test('hands back exactly the scripted image', () async {
      const image = PickedImage(dataUri: 'data:image/jpeg;base64,QUJD', bytes: 3);
      final source = MockImageSource(next: image);
      expect(await source.pickFromCamera(), same(image));
    });
  });
}
