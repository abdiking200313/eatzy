/**
 * Per-service accent theming (issue #354 / P1-03).
 *
 * Ports flutter_app/lib/config/service_theme.dart token-for-token:
 * `ZivoServiceColors` -> `ServiceThemeColors`, `ServiceThemes` (the
 * `food`/`grocery`/`pharmacy`/`freshMeat`/`electronics`/`platform` palettes
 * plus `forId`/`forSlug`) -> the `ServiceThemes` object below. Colors are
 * copied as literal hex values straight from the Dart `Color(0x..)`
 * constants rather than derived from `tokens.ts`'s `primary`/`primarySoft`/
 * etc., because the Flutter palettes are their own fixed swatches per
 * service, independent of the neutral "platform" brand color.
 *
 * `platform` is the one exception: it mirrors `ZivoServiceColors.platform`,
 * which *is* wired to the neutral `TwColors` tokens (this port's
 * `tokens.ts` `colors.light`), used as the fallback for `ServiceId.unknown`.
 *
 * flutter_app has no dark `ThemeData` yet (see tokens.ts's own note), so
 * these palettes are light-mode-only, matching the Flutter source.
 */

import { colors as tokenColors } from '@/theme/tokens';

export interface ServiceThemeColors {
  accent: string;
  onAccent: string;
  soft: string;
  background: string;
  card: string;
  border: string;
}

/**
 * `app/service_module.dart`'s `ServiceId` enum. `unknown` is not a
 * purchasable service module — it exists only as a fallback for
 * activity/history rows whose `service_id` no longer matches a real module.
 */
export type ServiceId = 'food' | 'grocery' | 'pharmacy' | 'unknown';

/**
 * `ServiceDescriptor.slug` / `GroceryStoreType.dbValue` (`_` -> `-`) values
 * that get their own palette on top of their underlying `ServiceId`'s
 * engine. Fresh Meat and Electronics both run on the grocery engine
 * (`ServiceId.grocery`) but get their own look (owner decision, 2026-09-25).
 */
export type ServiceSlug = 'fresh-meat' | 'electronics';

export const ServiceThemes = {
  platform: {
    accent: tokenColors.light.primary,
    onAccent: tokenColors.light.onPrimary,
    soft: tokenColors.light.primarySoft,
    background: tokenColors.light.bg,
    card: tokenColors.light.card,
    border: tokenColors.light.border,
  },

  food: {
    accent: '#C2410C',
    onAccent: '#FFFFFF',
    soft: '#FFE8DC',
    background: '#FFF9F5',
    card: '#FFF1E9',
    border: '#F6C8B1',
  },

  grocery: {
    accent: '#15803D',
    onAccent: '#FFFFFF',
    soft: '#DCFCE7',
    background: '#F7FCF8',
    card: '#ECF9F0',
    border: '#B7E4C7',
  },

  pharmacy: {
    accent: '#7C3AED',
    onAccent: '#FFFFFF',
    soft: '#EDE9FE',
    background: '#FAF8FF',
    card: '#F4F1FE',
    border: '#D7CBFA',
  },

  // Fresh Meat and Electronics run on the grocery engine (ServiceId
  // 'grocery') but get their own look (owner decision, 2026-09-25); see
  // `forSlug`.
  freshMeat: {
    accent: '#B91C1C',
    onAccent: '#FFFFFF',
    soft: '#FEE2E2',
    background: '#FFF8F8',
    card: '#FEF0F0',
    border: '#F5C2C2',
  },

  electronics: {
    accent: '#1D4ED8',
    onAccent: '#FFFFFF',
    soft: '#DBEAFE',
    background: '#F7FAFF',
    card: '#EEF4FF',
    border: '#BFD3F8',
  },
} as const satisfies Record<string, ServiceThemeColors>;

/**
 * Palette for a home/services tile or store type by its slug
 * (`ServiceDescriptor.slug`, `GroceryStoreType.dbValue` with `_` -> `-`),
 * falling back to `forId`.
 */
export function forSlug(slug: string, id: ServiceId): ServiceThemeColors {
  switch (slug) {
    case 'fresh-meat':
      return ServiceThemes.freshMeat;
    case 'electronics':
      return ServiceThemes.electronics;
    default:
      return forId(id);
  }
}

export function forId(id: ServiceId): ServiceThemeColors {
  switch (id) {
    case 'food':
      return ServiceThemes.food;
    case 'grocery':
      return ServiceThemes.grocery;
    case 'pharmacy':
      return ServiceThemes.pharmacy;
    // No dedicated palette for a fallback/legacy service — reuse the
    // neutral platform colors instead of inventing a new accent.
    case 'unknown':
      return ServiceThemes.platform;
  }
}
