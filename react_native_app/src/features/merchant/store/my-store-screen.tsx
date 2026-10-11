/**
 * Ports `flutter_app/lib/features/merchant/store/presentation/my_store_screen.dart`
 * (issue #407 / P9-02): "My Store" -- view and edit the signed-in merchant's
 * own store profile (name, description, address/area, open/closed), or
 * create one if they don't have one yet. Scoped entirely by `owner_id`; see
 * `api/merchant-store-repository.ts` for the RLS this mirrors.
 *
 * States, as in the Dart screen: a spinner on first load; an error view
 * with "Try again" when the load fails and no store is held; the
 * create-store empty state; and the edit form once a store is loaded.
 *
 * Photos (issue #411 / P9-06): both the create and edit forms use the shared
 * `MerchantPhotoField` to pick, crop (16:9 banner) and upload a store
 * photo; a `MerchantPhotoSession` deletes replaced uploads after a save and
 * abandoned ones when the form goes away. Saving is held off while an
 * upload is in flight, as in Dart.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Switch, Text, View } from 'react-native';

import { AppTextField } from '@/components/app-text-field';
import { CartSnackbar } from '@/components/cart-snackbar';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { radius, spacing } from '@/theme/tokens';

import { SupabaseMerchantMediaStore, type MerchantMediaStore } from '../shared/merchant-media-store';
import { MerchantPhotoField, useMerchantPhotoSession } from '../shared/merchant-photo-field';
import type { MerchantPhotoPicker } from '../shared/pick-merchant-photo';
import type { MerchantStore } from './api/merchant-store';
import { MERCHANT_VERTICALS, MERCHANT_VERTICAL_CONFIG, type MerchantVertical } from './api/merchant-vertical';
import { MerchantStoreController, useMerchantStoreState } from './merchant-store-controller';

export type MyStoreScreenProps = {
  /** The signed-in merchant's `profiles.id` (== `auth.uid()`). */
  ownerId: string;
  /** Overridable for tests (and for a shell that shares one controller); defaults to a Supabase-backed controller. */
  controller?: MerchantStoreController;
  /** Overridable for tests; defaults to the Supabase `merchant_media` bucket. */
  media?: MerchantMediaStore;
  /** Overridable for tests; defaults to the device picker + crop. */
  photoPicker?: MerchantPhotoPicker;
};

const NAME_REQUIRED_MESSAGE = 'Enter a store name.';

export function MyStoreScreen({ ownerId, controller: controllerProp, media: mediaProp, photoPicker }: MyStoreScreenProps) {
  const [ownMedia] = useState<MerchantMediaStore>(() => mediaProp ?? new SupabaseMerchantMediaStore());
  const media = mediaProp ?? ownMedia;
  const [ownController] = useState(() => (controllerProp ? null : new MerchantStoreController()));
  const controller = controllerProp ?? ownController!;
  const state = useMerchantStoreState(controller);
  const snackbar = useCartSnackbar();

  useEffect(() => {
    if (!controller.hasLoaded && !controller.isLoading) {
      void controller.load(ownerId);
    }
  }, [controller, ownerId]);

  let body;
  if (!state.hasLoaded && (state.isLoading || state.loadError == null)) {
    body = <LoadingState />;
  } else if (state.loadError != null && state.store == null) {
    body = <ErrorState message={state.loadError} onRetry={() => void controller.load(ownerId)} />;
  } else if (state.store == null) {
    body = (
      <CreateStoreView
        controller={controller}
        ownerId={ownerId}
        media={media}
        photoPicker={photoPicker}
        onCreated={() => snackbar.show('Store created.')}
      />
    );
  } else {
    body = (
      <StoreForm
        key={state.store.id}
        controller={controller}
        store={state.store}
        ownerId={ownerId}
        media={media}
        photoPicker={photoPicker}
        onSaved={() => snackbar.show('Store saved.')}
      />
    );
  }

  return (
    <View className="relative flex-1">
      {body}
      <CartSnackbar message={snackbar.message} />
    </View>
  );
}

type CreateStoreViewProps = {
  controller: MerchantStoreController;
  ownerId: string;
  media: MerchantMediaStore;
  photoPicker?: MerchantPhotoPicker;
  onCreated: () => void;
};

/**
 * Empty state: the merchant has no store yet in any vertical. Lets them
 * pick a vertical and create one -- required so a brand-new merchant
 * account has any way to reach the catalog screen at all.
 */
function CreateStoreView({ controller, ownerId, media, photoPicker, onCreated }: CreateStoreViewProps) {
  const colors = useSemanticColors();
  const { isSaving, saveError } = useMerchantStoreState(controller);
  const [vertical, setVertical] = useState<MerchantVertical>('food');
  const [name, setName] = useState('');
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [nameError, setNameError] = useState<string | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const photos = useMerchantPhotoSession(media, null);
  const config = MERCHANT_VERTICAL_CONFIG[vertical];

  const submit = async () => {
    if (name.trim().length === 0) {
      setNameError(NAME_REQUIRED_MESSAGE);
      return;
    }
    setNameError(null);
    const succeeded = await photos.save(imageUrl, () =>
      controller.createStore({
        vertical,
        ownerId,
        name,
        location,
        description: config.storeSupportsDescription ? description : null,
        imageUrl,
      }),
    );
    if (succeeded) onCreated();
  };

  return (
    <ScrollView contentContainerStyle={{ paddingHorizontal: spacing.screenX, paddingVertical: spacing.x6 }}>
      <View className="items-center">
        <MaterialIcons name="storefront" size={48} color={colors.textMuted} />
      </View>
      <Text style={{ marginTop: spacing.x3 }} className="text-center text-textLg font-outfitBold text-text">
        {"You don't have a store yet"}
      </Text>
      <Text style={{ marginTop: spacing.x1 }} className="text-center text-textSm font-outfitRegular text-textMuted">
        Choose a service and set up your store profile to start selling.
      </Text>

      <View style={{ marginTop: spacing.x5 }}>
        <VerticalPicker value={vertical} onChange={setVertical} />
      </View>

      <View style={{ marginTop: spacing.x4, gap: spacing.x3 }}>
        <View>
          <AppTextField hint="Store name" label="Store name" value={name} onChangeText={setName} autoCapitalize="words" />
          <FieldError message={nameError} />
        </View>
        <AppTextField hint={config.storeLocationLabel} label={config.storeLocationLabel} value={location} onChangeText={setLocation} />
        {config.storeSupportsDescription && (
          <AppTextField
            hint="Description"
            label="Description"
            value={description}
            onChangeText={setDescription}
            multiline
            numberOfLines={3}
          />
        )}
      </View>

      <View style={{ marginTop: spacing.x4 }}>
        <MerchantPhotoField
          testID="store-photo"
          label="Store photo"
          imageUrl={imageUrl}
          folder="store"
          session={photos}
          picker={photoPicker}
          onChange={setImageUrl}
          onUploadingChange={setIsUploading}
        />
      </View>

      <FieldError message={saveError} />

      <View style={{ marginTop: spacing.x6 }}>
        <FilledButton label="Create store" busy={isSaving} disabled={isUploading} onPress={() => void submit()} />
      </View>
    </ScrollView>
  );
}

type StoreFormProps = {
  controller: MerchantStoreController;
  store: MerchantStore;
  ownerId: string;
  media: MerchantMediaStore;
  photoPicker?: MerchantPhotoPicker;
  onSaved: () => void;
};

/** Loaded state: edit the merchant's existing store. */
function StoreForm({ controller, store, ownerId, media, photoPicker, onSaved }: StoreFormProps) {
  const colors = useSemanticColors();
  const { isSaving, saveError } = useMerchantStoreState(controller);
  const [name, setName] = useState(store.name);
  const [location, setLocation] = useState(store.location);
  const [description, setDescription] = useState(store.description ?? '');
  const [isOpen, setIsOpen] = useState(store.isOpen);
  const [nameError, setNameError] = useState<string | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(store.imageUrl);
  const [isUploading, setIsUploading] = useState(false);
  const photos = useMerchantPhotoSession(media, store.imageUrl);
  const config = MERCHANT_VERTICAL_CONFIG[store.vertical];

  const submit = async () => {
    if (name.trim().length === 0) {
      setNameError(NAME_REQUIRED_MESSAGE);
      return;
    }
    setNameError(null);
    const succeeded = await photos.save(imageUrl, () =>
      controller.updateStore({
        ownerId,
        name,
        location,
        isOpen,
        description: config.storeSupportsDescription ? description : null,
        imageUrl,
      }),
    );
    if (succeeded) onSaved();
  };

  return (
    <ScrollView contentContainerStyle={{ paddingHorizontal: spacing.screenX, paddingVertical: spacing.x6 }}>
      <View className="flex-row items-center">
        <MaterialIcons name="storefront" size={24} color={colors.primary} />
        <Text style={{ marginLeft: spacing.x2 }} className="text-textBase font-outfitSemiBold text-text">
          {`${config.displayName} store`}
        </Text>
      </View>

      <View style={{ marginTop: spacing.x4, gap: spacing.x3 }}>
        <View>
          <AppTextField hint="Store name" label="Store name" value={name} onChangeText={setName} autoCapitalize="words" />
          <FieldError message={nameError} />
        </View>
        <AppTextField hint={config.storeLocationLabel} label={config.storeLocationLabel} value={location} onChangeText={setLocation} />
        {config.storeSupportsDescription && (
          <AppTextField
            hint="Description"
            label="Description"
            value={description}
            onChangeText={setDescription}
            multiline
            numberOfLines={3}
          />
        )}
      </View>

      <View style={{ marginTop: spacing.x4 }}>
        <MerchantPhotoField
          testID="store-photo"
          label="Store photo"
          imageUrl={imageUrl}
          folder="store"
          session={photos}
          picker={photoPicker}
          onChange={setImageUrl}
          onUploadingChange={setIsUploading}
        />
      </View>

      <View style={{ marginTop: spacing.x2, paddingVertical: spacing.x2 }} className="flex-row items-center">
        <View className="flex-1">
          <Text className="text-textBase font-outfitMedium text-text">Open for business</Text>
          <Text className="text-textSm font-outfitRegular text-textMuted">
            {isOpen ? 'Customers can see and order from this store.' : 'This store is hidden from customers.'}
          </Text>
        </View>
        <Switch
          accessibilityLabel="Open for business"
          value={isOpen}
          onValueChange={setIsOpen}
          thumbColor={isOpen ? colors.primary : undefined}
          trackColor={{ false: colors.textMuted, true: colors.primarySoft }}
        />
      </View>

      <FieldError message={saveError} />

      <View style={{ marginTop: spacing.x6 }}>
        <FilledButton label="Save changes" busy={isSaving} disabled={isUploading} onPress={() => void submit()} />
      </View>
      <View style={{ marginTop: spacing.x3 }}>
        <OutlinedButton
          label="Manage catalog"
          icon="menu-book"
          onPress={() => router.push(AppRoutes.merchantCatalog)}
        />
      </View>
    </ScrollView>
  );
}

/** Mirrors the Dart `SegmentedButton<MerchantVertical>`. */
function VerticalPicker({ value, onChange }: { value: MerchantVertical; onChange: (vertical: MerchantVertical) => void }) {
  const colors = useSemanticColors();
  return (
    <View
      accessibilityRole="radiogroup"
      style={{ borderColor: colors.borderStrong, borderRadius: radius.xl, borderWidth: 1 }}
      className="flex-row overflow-hidden">
      {MERCHANT_VERTICALS.map((vertical, index) => {
        const selected = vertical === value;
        return (
          <Pressable
            key={vertical}
            accessibilityRole="radio"
            accessibilityState={{ selected }}
            onPress={() => onChange(vertical)}
            style={{
              flex: 1,
              paddingVertical: spacing.x3,
              backgroundColor: selected ? colors.primarySoft : 'transparent',
              borderLeftWidth: index === 0 ? 0 : 1,
              borderLeftColor: colors.borderStrong,
            }}
            className="items-center">
            <Text className={selected ? 'text-textSm font-outfitSemiBold text-primary' : 'text-textSm font-outfitMedium text-text'}>
              {MERCHANT_VERTICAL_CONFIG[vertical].displayName}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

function FieldError({ message }: { message: string | null }) {
  if (message == null) return null;
  return (
    <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-error">
      {message}
    </Text>
  );
}

/**
 * Mirrors the Dart `FilledButton` whose child swaps to a small spinner (and
 * which disables) while saving; `disabled` alone (an upload in flight)
 * disables it without the spinner.
 */
function FilledButton({
  label,
  busy,
  disabled = false,
  onPress,
}: {
  label: string;
  busy: boolean;
  disabled?: boolean;
  onPress: () => void;
}) {
  const colors = useSemanticColors();
  const isDisabled = busy || disabled;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: isDisabled, busy }}
      disabled={isDisabled}
      onPress={onPress}
      style={{ backgroundColor: colors.primary, paddingVertical: spacing.x4, opacity: isDisabled ? 0.7 : 1 }}
      className="items-center justify-center rounded-xl active:opacity-80">
      {busy ? (
        <ActivityIndicator size="small" color={colors.onPrimary} />
      ) : (
        <Text style={{ color: colors.onPrimary }} className="text-button font-outfitSemiBold">
          {label}
        </Text>
      )}
    </Pressable>
  );
}

function OutlinedButton({
  label,
  icon,
  onPress,
}: {
  label: string;
  icon: keyof typeof MaterialIcons.glyphMap;
  onPress: () => void;
}) {
  const colors = useSemanticColors();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={{ borderColor: colors.borderStrong, borderWidth: 1, paddingVertical: spacing.x4 }}
      className="flex-row items-center justify-center rounded-xl active:opacity-70">
      <MaterialIcons name={icon} size={20} color={colors.primary} />
      <Text style={{ marginLeft: spacing.x2 }} className="text-button font-outfitSemiBold text-primary">
        {label}
      </Text>
    </Pressable>
  );
}
