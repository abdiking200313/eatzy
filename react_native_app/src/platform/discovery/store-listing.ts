/**
 * Ports `flutter_app/lib/platform/discovery/store_listing.dart`'s
 * `StoreListing` (issue #373 / P4-02): the shared shape
 * `StoreListingRepository` maps restaurant/grocery-store/pharmacy-store rows
 * into, so the home screen's "Popular Stores" section (and, later, Explore)
 * can render all three verticals through one component.
 */
import type { ServiceId } from '@/theme/service-theme';

export interface StoreListing {
  id: string;
  /** 'food', 'grocery', or 'pharmacy' -- never 'unknown'. */
  serviceId: ServiceId;
  name: string;
  subtitle: string;
  /** Null or empty means "no photo". */
  imageUrl: string | null;
  /** Expo Router path to open when this store is tapped. */
  route: string;
}
