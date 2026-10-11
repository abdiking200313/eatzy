/**
 * Ports `flutter_app/lib/features/merchant/catalog/presentation/catalog_screen.dart`
 * (issue #410 / P9-05): list, add, edit, delete, and toggle availability for
 * the merchant's own items -- `menu_items` / `grocery_products` /
 * `pharmacy_products` depending on the store's vertical.
 *
 * As in Dart, the screen either gets its store (`vertical` + `storeId` +
 * `storeName`) handed to it, or -- on the `/merchant/catalog` route, which
 * My Store's "Manage catalog" button pushes without params, and on a deep
 * link -- resolves the signed-in merchant's own store itself through
 * `MerchantStoreController` (a merchant owns at most one store).
 *
 * States, as in Dart: a spinner while the store/catalog first loads; a
 * "Set up your store first" view when the merchant has no store; an error
 * view with "Try again" when the load fails and no items are held; the
 * "No items yet" empty state with an add action; and the item list with
 * pull-to-refresh. The add/edit form opens in a modal sheet; delete asks
 * for confirmation first.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Alert, FlatList, Modal, Pressable, RefreshControl, Switch, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { OutlinedCard } from '@/components/outlined-card';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { formatCents } from '@/platform/money/format';
import { spacing } from '@/theme/tokens';

import type { MerchantVertical } from '../store/api/merchant-vertical';
import { MerchantStoreController, useMerchantStoreState } from '../store/merchant-store-controller';
import type { MerchantCatalogItem } from './api/merchant-catalog-item';
import type { MerchantCatalogRepository } from './api/merchant-catalog-repository';
import { CatalogItemForm } from './catalog-item-form';
import { MerchantCatalogController, useMerchantCatalogState } from './merchant-catalog-controller';

export type CatalogScreenProps = {
  /** Supplied together when the store is already known; omitted on the route/deep link, in which case the screen resolves them itself. */
  vertical?: MerchantVertical;
  storeId?: string;
  storeName?: string;
  /** The signed-in merchant's `profiles.id`; only used to self-resolve the store. `null` shows the "no store" view. */
  ownerId?: string | null;
  /** Overridable for tests; only used to self-resolve the store. */
  storeController?: MerchantStoreController;
  /** Overridable for tests; used for any controller this screen builds itself. */
  catalogRepository?: MerchantCatalogRepository;
  /** When supplied, the screen reads straight from it. */
  controller?: MerchantCatalogController;
};

type FormState = { open: false } | { open: true; initial: MerchantCatalogItem | null };

export function CatalogScreen({
  vertical: verticalProp,
  storeId: storeIdProp,
  storeName: storeNameProp,
  ownerId = null,
  storeController: storeControllerProp,
  catalogRepository,
  controller: controllerProp,
}: CatalogScreenProps) {
  const needsOwnStore = controllerProp == null && (verticalProp == null || storeIdProp == null);
  const [ownStoreController] = useState(() =>
    needsOwnStore && storeControllerProp == null ? new MerchantStoreController() : null,
  );
  const storeController = needsOwnStore ? (storeControllerProp ?? ownStoreController) : null;
  const storeState = useMerchantStoreState(storeController ?? PLACEHOLDER_STORE_CONTROLLER);
  const ownStore = storeController == null ? null : storeState.store;

  useEffect(() => {
    if (storeController != null && ownerId != null && !storeController.hasLoaded && !storeController.isLoading) {
      void storeController.load(ownerId);
    }
  }, [storeController, ownerId]);

  const vertical = controllerProp?.vertical ?? verticalProp ?? ownStore?.vertical ?? null;
  const storeId = controllerProp?.storeId ?? storeIdProp ?? ownStore?.id ?? null;
  const storeName = storeNameProp ?? ownStore?.name ?? 'My store';

  const ownController = useMemo(
    () =>
      controllerProp != null || vertical == null || storeId == null
        ? null
        : new MerchantCatalogController({ vertical, storeId, repository: catalogRepository }),
    [controllerProp, vertical, storeId, catalogRepository],
  );
  const controller = controllerProp ?? ownController;

  useEffect(() => {
    if (controller != null && !controller.hasLoaded && !controller.isLoading) {
      void controller.load();
    }
  }, [controller]);

  const [form, setForm] = useState<FormState>({ open: false });
  const openForm = useCallback((initial: MerchantCatalogItem | null = null) => setForm({ open: true, initial }), []);
  const closeForm = useCallback(() => setForm({ open: false }), []);

  let body;
  if (controller == null || vertical == null || storeId == null) {
    // Mirrors `_selfResolutionFinished`: with no owner, or once the store
    // lookup finished without a store, there is nothing left to wait on.
    if (ownerId == null || storeController == null) {
      body = <NoStoreView />;
    } else if (storeState.loadError != null && storeState.store == null) {
      // RN addition: Dart keeps spinning on a failed store lookup.
      body = <ErrorState message={storeState.loadError} onRetry={() => void storeController.load(ownerId)} />;
    } else {
      body = storeState.hasLoaded ? <NoStoreView /> : <LoadingState />;
    }
  } else {
    body = <CatalogBody controller={controller} onAdd={() => openForm()} onEdit={openForm} />;
  }

  return (
    <AppScaffold
      title={storeName}
      showBackButton
      floatingActionButton={controller == null ? undefined : <AddItemFab onPress={() => openForm()} />}>
      <Text
        style={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x2 }}
        className="text-textSm font-outfitMedium text-textMuted">
        Catalog
      </Text>
      {body}
      {controller != null && vertical != null && storeId != null && (
        <Modal visible={form.open} animationType="slide" presentationStyle="pageSheet" onRequestClose={closeForm}>
          {form.open && (
            <CatalogItemForm
              controller={controller}
              vertical={vertical}
              storeId={storeId}
              initial={form.initial}
              onDone={closeForm}
            />
          )}
        </Modal>
      )}
    </AppScaffold>
  );
}

/**
 * `useSyncExternalStore` needs a stable controller even when this screen
 * isn't self-resolving its store; this one is never loaded, so it never
 * emits or touches Supabase.
 */
const PLACEHOLDER_STORE_CONTROLLER = new MerchantStoreController({
  repository: {
    fetchOwnStore: () => Promise.resolve(null),
    createStore: () => Promise.reject(new Error('unused')),
    updateStore: () => Promise.reject(new Error('unused')),
  },
});

type CatalogBodyProps = {
  controller: MerchantCatalogController;
  onAdd: () => void;
  onEdit: (item: MerchantCatalogItem) => void;
};

function CatalogBody({ controller, onAdd, onEdit }: CatalogBodyProps) {
  const colors = useSemanticColors();
  const state = useMerchantCatalogState(controller);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const refresh = useCallback(async () => {
    setIsRefreshing(true);
    try {
      await controller.load();
    } finally {
      setIsRefreshing(false);
    }
  }, [controller]);

  const confirmDelete = useCallback(
    (item: MerchantCatalogItem) => {
      Alert.alert('Delete item?', `"${item.name}" will be removed from your catalog.`, [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Delete', style: 'destructive', onPress: () => void controller.deleteItem(item) },
      ]);
    },
    [controller],
  );

  if (!state.hasLoaded && (state.isLoading || state.loadError == null)) {
    return <LoadingState />;
  }
  if (state.loadError != null && state.items.length === 0) {
    return <ErrorState message={state.loadError} onRetry={() => void controller.load()} />;
  }
  if (state.items.length === 0) {
    return (
      <View className="flex-1">
        <EmptyState icon="inventory-2" title="No items yet" message="Add your first item to start selling." />
        <View style={{ paddingHorizontal: spacing.screenX, paddingBottom: spacing.x12 * 2 }} className="items-center">
          <Pressable
            testID="catalog-empty-add"
            accessibilityRole="button"
            accessibilityLabel="Add item"
            onPress={onAdd}
            className="flex-row items-center rounded-lg bg-primary px-x5 py-x3 active:opacity-80">
            <MaterialIcons name="add" size={20} color={colors.onPrimary} />
            <Text style={{ marginLeft: spacing.x2 }} className="text-button font-outfitSemiBold text-onPrimary">
              Add item
            </Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return (
    <FlatList
      testID="catalog-list"
      data={state.items}
      keyExtractor={(item) => item.id}
      contentContainerStyle={{
        paddingHorizontal: spacing.screenX,
        paddingTop: spacing.x4,
        paddingBottom: spacing.x12 * 2,
        gap: spacing.x2,
      }}
      refreshControl={<RefreshControl refreshing={isRefreshing} onRefresh={refresh} />}
      renderItem={({ item }) => (
        <CatalogItemTile
          item={item}
          onEdit={() => onEdit(item)}
          onDelete={() => confirmDelete(item)}
          onToggleAvailability={() => void controller.toggleAvailability(item)}
        />
      )}
    />
  );
}

type CatalogItemTileProps = {
  item: MerchantCatalogItem;
  onEdit: () => void;
  onDelete: () => void;
  onToggleAvailability: () => void;
};

function CatalogItemTile({ item, onEdit, onDelete, onToggleAvailability }: CatalogItemTileProps) {
  const colors = useSemanticColors();
  const description = item.description?.trim() ?? '';
  return (
    <OutlinedCard padding={0}>
      <View
        style={{ paddingHorizontal: spacing.x3_5, paddingVertical: spacing.listRowY }}
        className="flex-row items-start">
        <View className="flex-1">
          <Text className="text-textBase font-outfitSemiBold text-text">{item.name}</Text>
          {description.length > 0 && (
            <Text style={{ marginTop: 3 }} numberOfLines={2} className="text-textSm font-outfitRegular text-textMuted">
              {item.description}
            </Text>
          )}
          <Text style={{ marginTop: 6 }} className="text-textSm font-outfitSemiBold text-text">
            {formatCents(item.priceCents)}
          </Text>
        </View>
        <View className="items-end">
          <Switch
            accessibilityLabel={`${item.name} available`}
            value={item.isAvailable}
            onValueChange={onToggleAvailability}
            thumbColor={item.isAvailable ? colors.primary : undefined}
            trackColor={{ false: colors.textMuted, true: colors.primarySoft }}
          />
          <View className="flex-row">
            <IconAction label="Edit" icon="edit" onPress={onEdit} />
            <IconAction label="Delete" icon="delete-outline" onPress={onDelete} />
          </View>
        </View>
      </View>
    </OutlinedCard>
  );
}

function IconAction({
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
      className="h-x10 w-x10 items-center justify-center active:opacity-70">
      <MaterialIcons name={icon} size={22} color={colors.text} />
    </Pressable>
  );
}

/** Mirrors the Dart `FloatingActionButton.extended(icon: add, label: 'Add item')`. */
function AddItemFab({ onPress }: { onPress: () => void }) {
  const colors = useSemanticColors();
  return (
    <Pressable
      testID="catalog-add-fab"
      accessibilityRole="button"
      accessibilityLabel="Add item"
      onPress={onPress}
      style={{ backgroundColor: colors.primary, paddingHorizontal: spacing.x5, paddingVertical: spacing.x4 }}
      className="flex-row items-center rounded-2xl active:opacity-80">
      <MaterialIcons name="add" size={22} color={colors.onPrimary} />
      <Text style={{ marginLeft: spacing.x2, color: colors.onPrimary }} className="text-button font-outfitSemiBold">
        Add item
      </Text>
    </Pressable>
  );
}

/** Mirrors the Dart `_NoStoreView`. */
function NoStoreView() {
  return (
    <EmptyState
      icon="storefront"
      title="Set up your store first"
      message={'Set up your store from the "My Store" tab to manage its catalog.'}
    />
  );
}
