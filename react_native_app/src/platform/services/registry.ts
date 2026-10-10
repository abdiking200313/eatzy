/**
 * Ports `flutter_app/lib/app/service_module.dart`'s `ServiceRegistry`
 * (issue #371 / P4-05): the single source listing every purchasable
 * service tile (home grid, Services list) plus the "coming soon"
 * placeholders, so those screens (#373/#374) render from one shared list
 * instead of each hard-coding their own.
 *
 * `ServiceId` and the per-service accent palette already exist --
 * `src/theme/service-theme.ts` (issue #354 / P1-03) ported those ahead of
 * this file. This file only adds the tile metadata (title, description,
 * route, icon, coming-soon flag) on top of that id.
 */
import { MaterialIcons } from '@expo/vector-icons';

import { AppRoutes } from '@/platform/navigation/app-routes';
import type { ServiceId } from '@/theme/service-theme';

export type ServiceIconName = keyof typeof MaterialIcons.glyphMap;

export interface ServiceDescriptor {
  id: ServiceId;
  title: string;
  description: string;
  entryRoute: string;
  icon: ServiceIconName;
  /** When set, a tile should show this photo instead of `icon`. */
  photoUrl?: string;
  /**
   * Unique per tile, for list keys. Defaults to `id` when omitted; set when
   * several tiles share one engine (Fresh Meat and Electronics are both
   * `grocery` store lists, told apart by slug, not id).
   */
  slug: string;
}

/**
 * A category announced on the home grid and the Services list before any
 * service backs it -- tapping it only says it is coming soon. Kept out of
 * `ServiceRegistry.modules` on purpose: those are real routed modules,
 * while a placeholder has no `ServiceId`, entry route, or palette.
 */
export interface ComingSoonCategory {
  id: string;
  title: string;
  description: string;
  icon: ServiceIconName;
  photoUrl?: string;
}

const ICON_BUCKET_URL =
  'https://jzubookmbrtslocuzepe.supabase.co/storage/v1/object/public/product_icons';

function descriptor(options: Omit<ServiceDescriptor, 'slug'> & { slug?: string }): ServiceDescriptor {
  return { ...options, slug: options.slug ?? options.id };
}

// Order is the display order on the home grid and the Services list.
const MODULES: ServiceDescriptor[] = [
  descriptor({
    id: 'grocery',
    title: 'Grocery',
    description: 'Everyday essentials delivered',
    entryRoute: AppRoutes.grocery,
    icon: 'local-grocery-store',
    photoUrl: `${ICON_BUCKET_URL}/service-grocery.png`,
  }),
  descriptor({
    id: 'food',
    title: 'Food',
    description: 'Meals from nearby restaurants',
    entryRoute: AppRoutes.food,
    icon: 'restaurant',
    photoUrl: `${ICON_BUCKET_URL}/service-food.jpg`,
  }),
  descriptor({
    id: 'pharmacy',
    title: 'Pharmacy',
    description: 'Over-the-counter health essentials',
    entryRoute: AppRoutes.pharmacy,
    icon: 'local-pharmacy',
    photoUrl: `${ICON_BUCKET_URL}/service-pharmacy.jpg`,
  }),
  descriptor({
    id: 'grocery',
    slug: 'fresh-meat',
    title: 'Fresh Meat',
    description: 'Fresh cuts from local butchers',
    entryRoute: AppRoutes.freshMeat,
    icon: 'kebab-dining',
    photoUrl: `${ICON_BUCKET_URL}/service-fresh-meat.jpg`,
  }),
  descriptor({
    id: 'grocery',
    slug: 'electronics',
    title: 'Electronics',
    description: 'Phones, gadgets and accessories',
    entryRoute: AppRoutes.electronics,
    icon: 'devices',
    photoUrl: `${ICON_BUCKET_URL}/service-electronics.jpg`,
  }),
];

// Categories with no logic behind them yet; shown after `modules`.
const COMING_SOON: ComingSoonCategory[] = [
  {
    id: 'delivery',
    title: 'Delivery',
    description: 'Send parcels and errands across town',
    icon: 'local-shipping',
  },
  {
    id: 'deals',
    title: 'Deals',
    description: 'Discounts and offers from nearby shops',
    icon: 'local-offer',
  },
];

// Generic descriptor for `ServiceId` `'unknown'` and any other id with no
// entry in `modules` -- defensive fallback rather than throwing. Mirrors
// `ServiceRegistry.unknownModule`.
const UNKNOWN_MODULE: ServiceDescriptor = descriptor({
  id: 'unknown',
  title: 'Other',
  description: 'Activity from a service that is no longer available',
  entryRoute: '',
  icon: 'receipt-long',
});

export const ServiceRegistry = {
  modules: MODULES,
  comingSoon: COMING_SOON,
  unknownModule: UNKNOWN_MODULE,

  /** Mirrors `ServiceRegistry.byId`. */
  byId(id: ServiceId): ServiceDescriptor {
    return MODULES.find((module) => module.id === id) ?? UNKNOWN_MODULE;
  },
};
