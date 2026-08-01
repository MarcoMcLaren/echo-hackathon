// Photos, over a radio. Ported from src/features/messaging/api/attachments.ts.
//
// Nearby carries a 32 KiB BYTES payload, so a photo travels as chunks (see
// utils/relay.dart). That makes size the whole design problem: every extra
// kilobyte is another hop-by-hop round trip. We ask the picker for something
// small rather than sending what the camera produces.
import 'dart:convert';
import 'dart:math';

import 'package:image_picker/image_picker.dart';

import '../../utils/relay.dart' show chunkChars;

/// Long edge, in pixels. Big enough to read a face, small enough to arrive.
const maxImageEdge = 900.0;

/// JPEG quality, on image_picker's 0-100 scale (RN's expo-image-picker uses a
/// 0-1 scale where 0.35 is "deliberately low, this is a radio, not a photo
/// album" — the same intent here is imageQuality: 35).
const maxImageQuality = 35;

/// Refuse anything that would take absurdly long to hop. ~40 chunks.
const maxImageChars = 900000;

class PickedImage {
  final String dataUri; // "data:image/jpeg;base64,..."
  final int bytes; // length of the base64 payload — used for the size guard
  const PickedImage({required this.dataUri, required this.bytes});
}

final ImagePicker _picker = ImagePicker();

Future<PickedImage?> _toResult(XFile? file) async {
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final b64 = base64Encode(bytes);
  return PickedImage(dataUri: 'data:image/jpeg;base64,$b64', bytes: b64.length);
}

/// Choose an existing photo. Android's photo picker needs no permission.
Future<PickedImage?> pickFromLibrary() async {
  final file = await _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: maxImageEdge,
    maxHeight: maxImageEdge,
    imageQuality: maxImageQuality,
  );
  return _toResult(file);
}

/// Take one now. Returns null if the user backs out or denies the camera.
Future<PickedImage?> pickFromCamera() async {
  try {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxImageEdge,
      maxHeight: maxImageEdge,
      imageQuality: maxImageQuality,
    );
    return await _toResult(file);
  } catch (_) {
    // Camera permission denied, or no camera available — same "just null"
    // outcome RN gets from a failed requestCameraPermissionsAsync().
    return null;
  }
}

/// How many hops-worth of payload this is, for telling the user the truth.
/// Defaults to relay.dart's chunkChars so the estimate always matches how the
/// message actually gets split for the wire.
int chunkCount(int chars, [int size = chunkChars]) => max(1, (chars / size).ceil());
