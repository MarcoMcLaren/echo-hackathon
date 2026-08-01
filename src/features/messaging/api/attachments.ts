// Photos, over a radio.
//
// Nearby carries a 32 KiB BYTES payload, so a photo travels as chunks (see
// utils/relay). That makes size the whole design problem: every extra kilobyte
// is another hop-by-hop round trip. We ask the picker for something small
// rather than sending what the camera produces.
import * as ImagePicker from 'expo-image-picker';

/** Long edge, in pixels. Big enough to read a face, small enough to arrive. */
const MAX_EDGE = 900;

/** JPEG quality. Low, deliberately — this is a radio, not a photo album. */
const QUALITY = 0.35;

/** Refuse anything that would take absurdly long to hop. ~40 chunks. */
export const MAX_IMAGE_CHARS = 900_000;

export type PickedImage = { dataUri: string; bytes: number };

const toResult = (r: ImagePicker.ImagePickerResult): PickedImage | null => {
  if (r.canceled || !r.assets?.length) return null;
  const asset = r.assets[0];
  if (!asset.base64) return null;
  const dataUri = `data:image/jpeg;base64,${asset.base64}`;
  return { dataUri, bytes: asset.base64.length };
};

const options: ImagePicker.ImagePickerOptions = {
  mediaTypes: ['images'],
  quality: QUALITY,
  base64: true,
  // Cropping is the only size control the picker gives us, and it doubles as a
  // way to send the part that matters instead of the whole frame.
  allowsEditing: true,
};

/** Choose an existing photo. Android's photo picker needs no permission. */
export async function pickFromLibrary(): Promise<PickedImage | null> {
  return toResult(await ImagePicker.launchImageLibraryAsync(options));
}

/** Take one now. Returns null if the user backs out or denies the camera. */
export async function pickFromCamera(): Promise<PickedImage | null> {
  const permission = await ImagePicker.requestCameraPermissionsAsync();
  if (!permission.granted) return null;
  return toResult(await ImagePicker.launchCameraAsync(options));
}

/** How many hops-worth of payload this is, for telling the user the truth. */
export const chunkCount = (chars: number, chunkChars = 24_000) =>
  Math.max(1, Math.ceil(chars / chunkChars));

export { MAX_EDGE };
