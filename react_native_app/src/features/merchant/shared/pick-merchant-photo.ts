/**
 * Ports `pickAndCropMerchantPhoto` from
 * `flutter_app/lib/features/merchant/shared/merchant_photo_field.dart`
 * (issue #411 / P9-06): choose a photo from the library, crop it to the
 * folder's shape, and hand back JPEG bytes ready to upload.
 *
 * Dart uses `image_picker` + `image_cropper` (a separate locked-aspect crop
 * screen). Expo has no cropper screen of its own, so:
 *   1. `expo-image-picker` with `allowsEditing` + `aspect` gives the merchant
 *      a crop step on device (Android honours the aspect; iOS's crop box is
 *      always square; web has no crop UI);
 *   2. `expo-image-manipulator` then centre-crops whatever came back to the
 *      exact folder aspect (a no-op when step 1 already matched), caps the
 *      width like Dart's `maxWidth`, and re-encodes as JPEG at 85% quality --
 *      so the stored shape is the same on every platform.
 */
import { ImageManipulator, SaveFormat } from 'expo-image-manipulator';
import * as ImagePicker from 'expo-image-picker';

import { MERCHANT_MEDIA_FOLDER_CONFIG, type MerchantMediaFolder } from './merchant-media-store';

/** A photo chosen and cropped on-device, ready to upload. */
export interface PickedMerchantPhoto {
  bytes: Uint8Array;
  contentType: string;
  /** A local URI to preview while the upload runs (the Dart `Image.memory(bytes)`). */
  previewUri: string;
}

/** Picks a photo for `folder`; resolves `null` when the merchant cancels. */
export type MerchantPhotoPicker = (folder: MerchantMediaFolder) => Promise<PickedMerchantPhoto | null>;

/** Dart's `pickImage(maxWidth: 2000, maxHeight: 2000)` cap, applied before the crop. */
const PICK_MAX_DIMENSION = 2000;
/** Dart's `compressQuality: 85`. */
const JPEG_QUALITY = 0.85;

export type CropRect = { originX: number; originY: number; width: number; height: number };

/** The largest centred rectangle of `width`x`height` with the `aspectX:aspectY` shape. */
export function centerCropRect(width: number, height: number, aspectX: number, aspectY: number): CropRect {
  const target = aspectX / aspectY;
  if (width / height > target) {
    const cropWidth = Math.max(1, Math.round(height * target));
    return { originX: Math.floor((width - cropWidth) / 2), originY: 0, width: cropWidth, height };
  }
  const cropHeight = Math.max(1, Math.round(width / target));
  return { originX: 0, originY: Math.floor((height - cropHeight) / 2), width, height: cropHeight };
}

const BASE64_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

/** Decodes standard (padded or unpadded) base64 into bytes. */
export function base64ToBytes(base64: string): Uint8Array {
  const clean = base64.replace(/[^A-Za-z0-9+/]/g, '');
  const bytes = new Uint8Array(Math.floor((clean.length * 3) / 4));
  let buffer = 0;
  let bits = 0;
  let index = 0;
  for (const char of clean) {
    buffer = (buffer << 6) | BASE64_ALPHABET.indexOf(char);
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      bytes[index++] = (buffer >> bits) & 0xff;
    }
  }
  return bytes.subarray(0, index);
}

/** Default {@link MerchantPhotoPicker}: library, then a crop locked to `folder`'s shape. */
export async function pickAndCropMerchantPhoto(folder: MerchantMediaFolder): Promise<PickedMerchantPhoto | null> {
  const { aspectX, aspectY, maxWidth } = MERCHANT_MEDIA_FOLDER_CONFIG[folder];
  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images'],
    allowsEditing: true,
    aspect: [aspectX, aspectY],
    quality: 1,
  });
  if (result.canceled || result.assets.length === 0) return null;
  const asset = result.assets[0];

  const context = ImageManipulator.manipulate(asset.uri);
  let width = asset.width;
  let height = asset.height;
  const longest = Math.max(width, height);
  if (longest > PICK_MAX_DIMENSION) {
    const scale = PICK_MAX_DIMENSION / longest;
    width = Math.round(width * scale);
    height = Math.round(height * scale);
    context.resize({ width, height });
  }
  // Some platforms (notably web) can report 0x0 for the picked asset; then
  // skip the exact crop and only cap the width.
  if (width > 0 && height > 0) {
    const crop = centerCropRect(width, height, aspectX, aspectY);
    if (crop.width !== width || crop.height !== height) context.crop(crop);
    if (crop.width > maxWidth) context.resize({ width: maxWidth });
  }

  const image = await context.renderAsync();
  const saved = await image.saveAsync({ format: SaveFormat.JPEG, compress: JPEG_QUALITY, base64: true });
  if (saved.base64 == null) throw new Error('Could not read the cropped photo.');
  return { bytes: base64ToBytes(saved.base64), contentType: 'image/jpeg', previewUri: saved.uri };
}
