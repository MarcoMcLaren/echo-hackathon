// Photos, over a radio.
//
// Nearby carries a 32 KiB BYTES payload, so a photo travels as chunks (see
// utils/relay). That makes size the whole design problem: every extra
// kilobyte is another hop-by-hop round trip.
//
// Port intent of src/features/messaging/api/attachments.ts. The real picker
// implementation needs an image-picker plugin (e.g. image_picker) that isn't
// wired up yet; this defines the contract [ImageSource] it must satisfy and a
// fake with a canned image for headless use.
import '../../utils/relay.dart' show chunkChars;

/// Refuse anything that would take absurdly long to hop. ~40 chunks.
const int maxImageChars = 900000;

class PickedImage {
  const PickedImage({required this.dataUri, required this.bytes});

  final String dataUri;
  final int bytes;
}

/// How many hops-worth of payload this is, for telling the user the truth.
int chunkCount(int chars, {int chunkSize = chunkChars}) {
  final n = (chars / chunkSize).ceil();
  return n < 1 ? 1 : n;
}

/// Contract a native image picker must satisfy.
abstract class ImageSource {
  /// Choose an existing photo. Returns null if the user backs out.
  Future<PickedImage?> pickFromLibrary();

  /// Take one now. Returns null if the user backs out or denies the camera.
  Future<PickedImage?> pickFromCamera();
}

/// Headless fake: hands back a canned image (or null, if scripted that way)
/// instead of opening a native picker/camera, so the compose flow can be
/// built and tested without one.
class MockImageSource implements ImageSource {
  MockImageSource({PickedImage? next}) : _next = next ?? _defaultImage;

  static const _defaultImage = PickedImage(
    dataUri: 'data:image/jpeg;base64,ZmFrZQ==',
    bytes: 6,
  );

  /// What the next pick returns. Set to null to simulate the user backing
  /// out or denying the camera.
  PickedImage? _next;

  set next(PickedImage? image) => _next = image;

  @override
  Future<PickedImage?> pickFromLibrary() async => _next;

  @override
  Future<PickedImage?> pickFromCamera() async => _next;
}
