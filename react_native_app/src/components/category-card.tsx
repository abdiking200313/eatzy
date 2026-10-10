import { MaterialIcons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { useState } from 'react';
import { ActivityIndicator, Pressable, Text, View } from 'react-native';

import type { Category } from '@/features/food/api/category';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { useServiceTheme } from '@/hooks/use-service-theme';
import type { ServiceId } from '@/theme/service-theme';
import { radius, spacing } from '@/theme/tokens';

export type CategoryCardProps = {
  category: Category;
  isSelected?: boolean;
  onPress: () => void;
  /**
   * Mirrors `StoreRowCard`/`CartAppBarAction`'s own `service` prop -- there
   * is no ambient `ZivoServiceTheme` in this app yet (see
   * `src/hooks/use-service-theme.ts`), so the caller passes its own
   * `ServiceId` explicitly. Categories are a food-only concept today, hence
   * the default.
   */
  service?: ServiceId;
};

// `CategoryCard`'s fixed tile size in category_card.dart.
const SIZE = 90;

/**
 * Ports `flutter_app/lib/services/food/presentation/widgets/category_card.dart`'s
 * `CategoryCard`: one food-home category chip -- a square photo tile (or a
 * broken-image fallback when there is no photo or it fails to load) plus a
 * name label below it, with a service-accent fill/border as the selection
 * indicator.
 */
export function CategoryCard({ category, isSelected = false, onPress, service = 'food' }: CategoryCardProps) {
  const colors = useSemanticColors();
  const palette = useServiceTheme(service);

  return (
    <View testID={`category-card-${category.id}`} style={{ width: SIZE }} className="items-center">
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={category.name}
        onPress={onPress}
        style={{
          width: SIZE,
          height: SIZE,
          borderRadius: radius.card,
          borderWidth: isSelected ? 2 : 1,
          borderColor: isSelected ? palette.accent : colors.border,
          backgroundColor: isSelected ? palette.soft : colors.card,
          overflow: 'hidden',
        }}
        className="items-center justify-center active:opacity-80">
        <CategoryImage imageUrl={category.iconUrl} accentColor={palette.accent} />
      </Pressable>
      <View style={{ height: spacing.x2 }} />
      <Text
        style={{ color: isSelected ? palette.accent : colors.textMuted }}
        className="text-textXs font-outfitMedium text-center"
        numberOfLines={1}>
        {category.name}
      </Text>
    </View>
  );
}

function CategoryImage({ imageUrl, accentColor }: { imageUrl: string; accentColor: string }) {
  const url = imageUrl.trim();
  const [status, setStatus] = useState<'loading' | 'loaded' | 'error'>(url ? 'loading' : 'error');

  if (!url || status === 'error') {
    return <MaterialIcons name="broken-image" size={34} color={accentColor} />;
  }

  return (
    <View style={{ width: SIZE, height: SIZE }}>
      <Image
        source={{ uri: url }}
        style={{ width: SIZE, height: SIZE }}
        contentFit="cover"
        cachePolicy="memory-disk"
        onLoad={() => setStatus('loaded')}
        onError={() => setStatus('error')}
      />
      {status === 'loading' && (
        <View className="absolute inset-0 items-center justify-center">
          <ActivityIndicator size="small" />
        </View>
      )}
    </View>
  );
}
