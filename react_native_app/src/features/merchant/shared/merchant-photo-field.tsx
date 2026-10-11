/**
 * Ports `MerchantPhotoField` from
 * `flutter_app/lib/features/merchant/shared/merchant_photo_field.dart`
 * (issue #411 / P9-06): the photo field for the merchant store and item
 * forms. Choose a photo from the device, crop it to the folder's shape,
 * upload it through `session`, and report the new URL through `onChange`.
 *
 * As in Dart: the preview keeps the folder's aspect (a full-width 16:9
 * banner for the store, a 160pt-wide square for items) and shows the local
 * photo with a spinner overlay while it uploads; "Upload photo" becomes
 * "Change photo" once there is a photo, with a "Remove" action beside it;
 * a failed pick or upload shows an inline error and keeps the old photo.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, Text, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, spacing } from '@/theme/tokens';

import {
  MERCHANT_MEDIA_FOLDER_CONFIG,
  MerchantPhotoSession,
  type MerchantMediaFolder,
  type MerchantMediaStore,
} from './merchant-media-store';
import { pickAndCropMerchantPhoto, type MerchantPhotoPicker } from './pick-merchant-photo';

export const PICK_FAILED_MESSAGE = 'Could not open your photos. Try again.';
export const UPLOAD_FAILED_MESSAGE = 'Upload failed. Check your connection and try again.';

export type MerchantPhotoFieldProps = {
  label: string;
  imageUrl: string | null;
  folder: MerchantMediaFolder;
  session: MerchantPhotoSession;
  /** Called with the uploaded URL, or `null` when the photo is removed. */
  onChange: (url: string | null) => void;
  /** Called when an upload starts/finishes, so the form can hold off saving until the URL is known. */
  onUploadingChange?: (isUploading: boolean) => void;
  /** Overridable for tests; defaults to {@link pickAndCropMerchantPhoto}. */
  picker?: MerchantPhotoPicker;
  /** Prefix for the preview's `testID`s (`<prefix>`, `<prefix>-placeholder`, `<prefix>-uploading`). */
  testID?: string;
};

export function MerchantPhotoField({
  label,
  imageUrl,
  folder,
  session,
  onChange,
  onUploadingChange,
  picker = pickAndCropMerchantPhoto,
  testID = 'merchant-photo',
}: MerchantPhotoFieldProps) {
  const colors = useSemanticColors();
  const [pendingUri, setPendingUri] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [failedUrl, setFailedUrl] = useState<string | null>(null);
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const url = imageUrl?.trim() ?? '';
  const hasPhoto = pendingUri != null || url.length > 0;
  const { aspectX, aspectY } = MERCHANT_MEDIA_FOLDER_CONFIG[folder];
  const isSquare = aspectX === aspectY;

  const chooseAndUpload = async () => {
    setError(null);
    let picked;
    try {
      picked = await picker(folder);
    } catch (pickError) {
      console.warn('MerchantPhotoField pick failed:', pickError);
      if (mounted.current) setError(PICK_FAILED_MESSAGE);
      return;
    }
    if (picked == null || !mounted.current) return;

    setPendingUri(picked.previewUri);
    setIsUploading(true);
    onUploadingChange?.(true);
    try {
      const uploaded = await session.upload({ bytes: picked.bytes, contentType: picked.contentType, folder });
      onChange(uploaded);
    } catch (uploadError) {
      console.warn('MerchantPhotoField upload failed:', uploadError);
      if (mounted.current) {
        setPendingUri(null);
        setError(UPLOAD_FAILED_MESSAGE);
      }
    } finally {
      if (mounted.current) setIsUploading(false);
      onUploadingChange?.(false);
    }
  };

  const remove = () => {
    setPendingUri(null);
    setError(null);
    onChange(null);
  };

  const previewUri = pendingUri ?? (url.length > 0 && failedUrl !== url ? url : null);

  return (
    <View>
      <Text style={{ marginBottom: spacing.x2 }} className="text-textSm font-outfitMedium text-text">
        {label}
      </Text>
      <View
        style={{
          aspectRatio: aspectX / aspectY,
          width: isSquare ? 160 : '100%',
          borderRadius: radius.lg,
          backgroundColor: colors.searchFill,
        }}
        className="items-center justify-center overflow-hidden">
        {previewUri != null ? (
          <Image
            testID={testID}
            accessibilityLabel={label}
            source={{ uri: previewUri }}
            style={{ width: '100%', height: '100%' }}
            contentFit="cover"
            cachePolicy="memory-disk"
            onError={() => {
              if (pendingUri == null) setFailedUrl(url);
            }}
          />
        ) : (
          <MaterialIcons
            testID={`${testID}-placeholder`}
            name={url.length > 0 ? 'broken-image' : 'add-photo-alternate'}
            size={36}
            color={colors.textMuted}
          />
        )}
        {isUploading && (
          <View
            testID={`${testID}-uploading`}
            style={{ position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: 'rgba(0,0,0,0.38)' }}
            className="items-center justify-center">
            <ActivityIndicator color="#ffffff" />
          </View>
        )}
      </View>

      <View style={{ marginTop: spacing.x2, gap: spacing.x2 }} className="flex-row flex-wrap">
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={hasPhoto ? 'Change photo' : 'Upload photo'}
          accessibilityState={{ disabled: isUploading }}
          disabled={isUploading}
          onPress={() => void chooseAndUpload()}
          style={{
            borderColor: colors.borderStrong,
            borderWidth: 1,
            paddingHorizontal: spacing.x4,
            paddingVertical: spacing.x2,
            opacity: isUploading ? 0.5 : 1,
          }}
          className="flex-row items-center rounded-xl active:opacity-70">
          <MaterialIcons name="photo-library" size={18} color={colors.primary} />
          <Text style={{ marginLeft: spacing.x2 }} className="text-textSm font-outfitSemiBold text-primary">
            {hasPhoto ? 'Change photo' : 'Upload photo'}
          </Text>
        </Pressable>
        {hasPhoto && (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Remove"
            accessibilityState={{ disabled: isUploading }}
            disabled={isUploading}
            onPress={remove}
            style={{ paddingHorizontal: spacing.x3, paddingVertical: spacing.x2, opacity: isUploading ? 0.5 : 1 }}
            className="items-center justify-center active:opacity-70">
            <Text className="text-textSm font-outfitSemiBold text-primary">Remove</Text>
          </Pressable>
        )}
      </View>

      {error != null && (
        <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-error">
          {error}
        </Text>
      )}
    </View>
  );
}

/**
 * One {@link MerchantPhotoSession} for the lifetime of a store/item form,
 * discarded (abandoned uploads deleted) when the form unmounts -- the Dart
 * forms' `initState` + `dispose() { _photos.discard(); }`.
 */
export function useMerchantPhotoSession(media: MerchantMediaStore, savedUrl: string | null | undefined): MerchantPhotoSession {
  const [session] = useState(() => new MerchantPhotoSession(media, savedUrl));
  useEffect(() => () => session.discard(), [session]);
  return session;
}
