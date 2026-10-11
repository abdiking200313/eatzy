/**
 * Ports `flutter_app/lib/features/merchant/catalog/presentation/catalog_item_form.dart`
 * (issue #410 / P9-05): the add/edit form for one catalog item, shown in a
 * bottom-sheet-style modal from `CatalogScreen`. Which fields show depends on
 * the vertical -- see `store/api/merchant-vertical.ts` /
 * `api/merchant-catalog-item.ts` for the columns each item table has.
 *
 * The Dart `DropdownButtonFormField`s (grocery pricing unit, pharmacy
 * category) become radio-style option rows, like My Store's vertical picker.
 *
 * Photos (issue #411 / P9-06): the shared `MerchantPhotoField` picks, crops
 * (square) and uploads an item photo; a `MerchantPhotoSession` deletes
 * replaced uploads after a save and abandoned ones when the form closes.
 * Saving is held off while an upload is in flight, as in Dart.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Switch, Text, View } from 'react-native';

import { AppTextField } from '@/components/app-text-field';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { parseToCents } from '@/platform/money/format';
import { radius, spacing } from '@/theme/tokens';

import type { MerchantMediaStore } from '../shared/merchant-media-store';
import { MerchantPhotoField, useMerchantPhotoSession } from '../shared/merchant-photo-field';
import type { MerchantPhotoPicker } from '../shared/pick-merchant-photo';
import type { MerchantVertical } from '../store/api/merchant-vertical';
import {
  GROCERY_PRICING_UNIT_LABEL,
  GROCERY_PRICING_UNITS,
  type GroceryPricingUnit,
  type MerchantCatalogItem,
} from './api/merchant-catalog-item';
import { useMerchantCatalogState, type MerchantCatalogController } from './merchant-catalog-controller';

export const NAME_REQUIRED_MESSAGE = 'Enter a name.';
export const INVALID_PRICE_MESSAGE = 'Enter a valid, non-negative price.';
export const INVALID_QUANTITY_MESSAGE = 'Enter a valid quantity.';
export const CATEGORY_REQUIRED_MESSAGE = 'Choose a category.';

export type CatalogItemFormProps = {
  controller: MerchantCatalogController;
  vertical: MerchantVertical;
  storeId: string;
  /** Where item photos are uploaded/deleted. */
  media: MerchantMediaStore;
  /** Overridable for tests; defaults to the device picker + crop. */
  photoPicker?: MerchantPhotoPicker;
  /** `null`/omitted when adding a new item; the existing item when editing. */
  initial?: MerchantCatalogItem | null;
  /** Called after a successful save -- the Dart `Navigator.pop()`. */
  onDone: () => void;
};

type FieldErrors = {
  name?: string;
  price?: string;
  availableQuantity?: string;
  category?: string;
  stockQuantity?: string;
};

/** Dart's `double.tryParse` on a trimmed string: any finite number, else `null`. */
function parseDecimal(text: string): number | null {
  const trimmed = text.trim();
  if (trimmed.length === 0) return null;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
}

/** Dart's `int.tryParse`: an optionally signed run of digits, else `null`. */
function parseInteger(text: string): number | null {
  const trimmed = text.trim();
  return /^[+-]?\d+$/.test(trimmed) ? Number.parseInt(trimmed, 10) : null;
}

export function CatalogItemForm({
  controller,
  vertical,
  storeId,
  media,
  photoPicker,
  initial = null,
  onDone,
}: CatalogItemFormProps) {
  const colors = useSemanticColors();
  const { isSaving, saveError, pharmacyCategories } = useMerchantCatalogState(controller);
  const isEditing = initial != null;

  const [name, setName] = useState(initial?.name ?? '');
  const [description, setDescription] = useState(initial?.description ?? '');
  const [price, setPrice] = useState(initial == null ? '' : (initial.priceCents / 100).toFixed(2));
  const [availableQuantity, setAvailableQuantity] = useState(
    initial?.availableQuantity == null ? '0' : String(initial.availableQuantity),
  );
  const [stockQuantity, setStockQuantity] = useState(initial?.stockQuantity == null ? '0' : String(initial.stockQuantity));
  const [isAvailable, setIsAvailable] = useState(initial?.isAvailable ?? true);
  const [pricingUnit, setPricingUnit] = useState<GroceryPricingUnit>(initial?.pricingUnit ?? 'each');
  const [categoryId, setCategoryId] = useState<string | null>(initial?.categoryId ?? null);
  const [errors, setErrors] = useState<FieldErrors>({});
  const [imageUrl, setImageUrl] = useState<string | null>(initial?.imageUrl ?? null);
  const [isUploading, setIsUploading] = useState(false);
  const photos = useMerchantPhotoSession(media, initial?.imageUrl);

  const submit = async () => {
    const priceCents = parseToCents(price);
    const parsedAvailable = parseDecimal(availableQuantity);
    const parsedStock = parseInteger(stockQuantity);

    const nextErrors: FieldErrors = {};
    if (name.trim().length === 0) nextErrors.name = NAME_REQUIRED_MESSAGE;
    if (priceCents == null) nextErrors.price = INVALID_PRICE_MESSAGE;
    if (vertical === 'grocery' && (parsedAvailable == null || parsedAvailable < 0)) {
      nextErrors.availableQuantity = INVALID_QUANTITY_MESSAGE;
    }
    if (vertical === 'pharmacy') {
      if (categoryId == null) nextErrors.category = CATEGORY_REQUIRED_MESSAGE;
      if (parsedStock == null || parsedStock < 0) nextErrors.stockQuantity = INVALID_QUANTITY_MESSAGE;
    }
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0 || priceCents == null) return;

    const draft: MerchantCatalogItem = {
      id: initial?.id ?? '',
      storeId,
      vertical,
      name,
      description,
      priceCents,
      isAvailable,
      imageUrl,
      pricingUnit: vertical === 'grocery' ? pricingUnit : null,
      availableQuantity: vertical === 'grocery' ? (parsedAvailable ?? 0) : null,
      categoryId: vertical === 'pharmacy' ? categoryId : null,
      stockQuantity: vertical === 'pharmacy' ? (parsedStock ?? 0) : null,
    };

    const succeeded = await photos.save(imageUrl, () =>
      isEditing ? controller.updateItem(draft) : controller.createItem(draft),
    );
    if (succeeded) onDone();
  };
  const submitDisabled = isSaving || isUploading;

  const priceLabel = vertical === 'grocery' ? 'Price (per unit, USD)' : 'Price (USD)';
  const submitLabel = isEditing ? 'Save item' : 'Add item';

  return (
    <ScrollView
      testID="catalog-item-form"
      keyboardShouldPersistTaps="handled"
      contentContainerStyle={{ paddingHorizontal: spacing.screenX, paddingVertical: spacing.x6 }}>
      <Text className="text-textXl font-outfitBold text-text">{isEditing ? 'Edit item' : 'Add item'}</Text>

      <View style={{ marginTop: spacing.x4, gap: spacing.x3 }}>
        <View>
          <AppTextField hint="Name" label="Name" value={name} onChangeText={setName} autoCapitalize="words" />
          <FieldError message={errors.name} />
        </View>
        <AppTextField
          hint="Description"
          label="Description"
          value={description}
          onChangeText={setDescription}
          multiline
          numberOfLines={2}
        />
        <View>
          <AppTextField
            hint={priceLabel}
            label={priceLabel}
            value={price}
            onChangeText={setPrice}
            keyboardType="decimal-pad"
            prefixIcon="attach-money"
          />
          <FieldError message={errors.price} />
        </View>
      </View>

      <View style={{ marginTop: spacing.x4 }}>
        <MerchantPhotoField
          testID="item-photo"
          label="Item photo"
          imageUrl={imageUrl}
          folder="items"
          session={photos}
          picker={photoPicker}
          onChange={setImageUrl}
          onUploadingChange={setIsUploading}
        />
      </View>

      {vertical === 'grocery' && (
        <View style={{ marginTop: spacing.x3, gap: spacing.x3 }}>
          <OptionGroup
            label="Sold"
            options={GROCERY_PRICING_UNITS.map((unit) => ({ value: unit, label: GROCERY_PRICING_UNIT_LABEL[unit] }))}
            value={pricingUnit}
            onChange={(value) => setPricingUnit(value as GroceryPricingUnit)}
          />
          <View>
            <AppTextField
              hint="Available quantity"
              label="Available quantity"
              value={availableQuantity}
              onChangeText={setAvailableQuantity}
              keyboardType="decimal-pad"
            />
            <FieldError message={errors.availableQuantity} />
          </View>
        </View>
      )}

      {vertical === 'pharmacy' && (
        <View style={{ marginTop: spacing.x3, gap: spacing.x3 }}>
          <View>
            <OptionGroup
              label="Category"
              options={pharmacyCategories.map((category) => ({ value: category.id, label: category.name }))}
              value={categoryId}
              onChange={setCategoryId}
            />
            <FieldError message={errors.category} />
          </View>
          <View>
            <AppTextField
              hint="Stock quantity"
              label="Stock quantity"
              value={stockQuantity}
              onChangeText={setStockQuantity}
              keyboardType="number-pad"
            />
            <FieldError message={errors.stockQuantity} />
          </View>
        </View>
      )}

      <View style={{ marginTop: spacing.x2, paddingVertical: spacing.x2 }} className="flex-row items-center">
        <View className="flex-1">
          <Text className="text-textBase font-outfitMedium text-text">Available</Text>
          <Text className="text-textSm font-outfitRegular text-textMuted">
            Turn off to hide this item from customers without deleting it.
          </Text>
        </View>
        <Switch
          accessibilityLabel="Available"
          value={isAvailable}
          onValueChange={setIsAvailable}
          thumbColor={isAvailable ? colors.primary : undefined}
          trackColor={{ false: colors.textMuted, true: colors.primarySoft }}
        />
      </View>

      <View style={{ marginTop: spacing.x6 }}>
        <FieldError message={saveError} />
        <View style={{ marginTop: saveError == null ? 0 : spacing.x2 }}>
          <Pressable
            testID="catalog-item-submit"
            accessibilityRole="button"
            accessibilityLabel={submitLabel}
            accessibilityState={{ disabled: submitDisabled, busy: isSaving }}
            disabled={submitDisabled}
            onPress={() => void submit()}
            style={{ backgroundColor: colors.primary, paddingVertical: spacing.x4, opacity: submitDisabled ? 0.7 : 1 }}
            className="items-center justify-center rounded-xl active:opacity-80">
            {isSaving ? (
              <ActivityIndicator size="small" color={colors.onPrimary} />
            ) : (
              <Text style={{ color: colors.onPrimary }} className="text-button font-outfitSemiBold">
                {submitLabel}
              </Text>
            )}
          </Pressable>
        </View>
      </View>
    </ScrollView>
  );
}

type Option = { value: string; label: string };

/** Stands in for the Dart `DropdownButtonFormField`: a labelled column of single-select rows. */
function OptionGroup({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: readonly Option[];
  value: string | null;
  onChange: (value: string) => void;
}) {
  const colors = useSemanticColors();
  return (
    <View>
      <Text style={{ marginBottom: spacing.x2 }} className="text-textSm font-outfitMedium text-text">
        {label}
      </Text>
      <View
        accessibilityRole="radiogroup"
        accessibilityLabel={label}
        style={{ borderColor: colors.borderStrong, borderRadius: radius.xl, borderWidth: 1 }}
        className="overflow-hidden">
        {options.length === 0 ? (
          <Text style={{ padding: spacing.x3 }} className="text-textSm font-outfitRegular text-textMuted">
            No options available.
          </Text>
        ) : (
          options.map((option, index) => {
            const selected = option.value === value;
            return (
              <Pressable
                key={option.value}
                accessibilityRole="radio"
                accessibilityLabel={option.label}
                accessibilityState={{ selected }}
                onPress={() => onChange(option.value)}
                style={{
                  paddingHorizontal: spacing.x4,
                  paddingVertical: spacing.x3,
                  backgroundColor: selected ? colors.primarySoft : 'transparent',
                  borderTopWidth: index === 0 ? 0 : 1,
                  borderTopColor: colors.borderStrong,
                }}
                className="flex-row items-center">
                <MaterialIcons
                  name={selected ? 'radio-button-checked' : 'radio-button-unchecked'}
                  size={20}
                  color={selected ? colors.primary : colors.textMuted}
                />
                <Text
                  style={{ marginLeft: spacing.x2 }}
                  className={selected ? 'text-textSm font-outfitSemiBold text-primary' : 'text-textSm font-outfitMedium text-text'}>
                  {option.label}
                </Text>
              </Pressable>
            );
          })
        )}
      </View>
    </View>
  );
}

function FieldError({ message }: { message: string | null | undefined }) {
  if (message == null) return null;
  return (
    <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-error">
      {message}
    </Text>
  );
}
