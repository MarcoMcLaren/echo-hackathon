// Photos, over a radio.
//
// Nearby carries a 32 KiB BYTES payload, so a photo travels as chunks (see
// utils/relay). That makes size the whole design problem: every extra
// kilobyte is another hop-by-hop round trip.
//
// Port intent of src/features/messaging/api/attachments.ts. This defines the
// contract [ImageSource] a picker must satisfy and the real
// [PickerImageSource] implementation backed by image_picker.
import 'dart:convert';

import 'package:image_picker/image_picker.dart' as picker;

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

/// Real photo/camera picker, downscaled and compressed at pick time — the
/// payload still has to hop the mesh in ~32 KiB chunks (see [chunkCount]), so
/// a full-resolution photo would take absurdly many hops.
///
/// The only import site for package:image_picker.
class PickerImageSource implements ImageSource {
  final picker.ImagePicker _picker = picker.ImagePicker();

  @override
  Future<PickedImage?> pickFromLibrary() => _pick(picker.ImageSource.gallery);

  @override
  Future<PickedImage?> pickFromCamera() => _pick(picker.ImageSource.camera);

  Future<PickedImage?> _pick(picker.ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final dataUri = 'data:${_mimeType(file.path)};base64,${base64Encode(bytes)}';
    return PickedImage(dataUri: dataUri, bytes: bytes.length);
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
