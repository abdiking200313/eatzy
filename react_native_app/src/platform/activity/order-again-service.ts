/**
 * Ports `flutter_app/lib/platform/activity/presentation/order_again_service.dart`
 * (`OrderAgainService`) -- issue #397 / P8-01 -- plus `runOrderAgain`, the
 * UI-independent half of `TrackOrderScreen._orderAgainPressed`
 * (`flutter_app/lib/features/orders/presentation/track_order_screen.dart`).
 *
 * "Order again" loads a past order's still-available items and puts them
 * into that vertical's cart, replacing whatever the cart held (the caller
 * asks first when the cart isn't empty). Uses the already-ported cart
 * stores (`food-cart-store.ts`, `grocery-cart-store.ts`,
 * `pharmacy-cart-store.ts`). In Flutter the "Order again" button lives on
 * the order details page, not the activity row (see
 * `activity_controller_test.dart`'s "No ... Order again on the row" check),
 * so the button itself is wired up by the track-order screen (#398 / P8-02).
 */
import type { ActivityItem } from '@/platform/activity/api/activity-item';
import { isReorderBasketEmpty, SupabaseOrderAgainRepository, type OrderAgainRepository, type ReorderBasket } from '@/platform/activity/api/order-again-repository';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { foodCartStore, type FoodCartState } from '@/stores/food-cart-store';
import { groceryCartStoreFor, type GroceryCartState, type GroceryStoreType } from '@/stores/grocery-cart-store';
import { pharmacyCartStore, type PharmacyCartState } from '@/stores/pharmacy-cart-store';

/** Anything with a Zustand-style `getState()` -- the cart store hooks themselves satisfy this. */
interface StateSource<T> {
  getState(): T;
}

export interface OrderAgainServiceOptions {
  repository?: OrderAgainRepository;
  foodCart?: StateSource<FoodCartState>;
  /** Picks the grocery cart for a store type (Grocery, Fresh Meat, Electronics). */
  groceryCart?: (storeType: GroceryStoreType) => StateSource<GroceryCartState>;
  pharmacyCart?: StateSource<PharmacyCartState>;
}

/** Ports `GroceryStoreType.cartRoute`. */
export function groceryCartRouteFor(storeType: GroceryStoreType): string {
  switch (storeType) {
    case 'fresh_meat':
      return AppRoutes.freshMeatCart;
    case 'electronics':
      return AppRoutes.electronicsCart;
    default:
      return AppRoutes.groceryCart;
  }
}

/** Ports `OrderAgainService.canReorder`: whether this row is a real order that can be placed again. */
export function canReorder(item: ActivityItem): boolean {
  return item.serviceId !== 'unknown';
}

export class OrderAgainService {
  private readonly repositoryOverride?: OrderAgainRepository;
  private readonly foodCart: StateSource<FoodCartState>;
  private readonly groceryCart: (storeType: GroceryStoreType) => StateSource<GroceryCartState>;
  private readonly pharmacyCart: StateSource<PharmacyCartState>;

  constructor(options: OrderAgainServiceOptions = {}) {
    this.repositoryOverride = options.repository;
    this.foodCart = options.foodCart ?? foodCartStore.store;
    this.groceryCart = options.groceryCart ?? ((storeType) => groceryCartStoreFor(storeType).store);
    this.pharmacyCart = options.pharmacyCart ?? pharmacyCartStore.store;
  }

  /** Resolved lazily, like the Dart `_source` getter, so a caller injecting a fake never touches the real client. */
  private get repository(): OrderAgainRepository {
    return this.repositoryOverride ?? new SupabaseOrderAgainRepository();
  }

  loadBasket(item: ActivityItem): Promise<ReorderBasket | null> {
    return this.repository.loadBasket({ serviceId: item.serviceId, orderId: item.id });
  }

  /** Ports `wouldReplaceCart`: whether filling `basket` would replace items already in a cart. */
  wouldReplaceCart(basket: ReorderBasket): boolean {
    switch (basket.kind) {
      case 'food':
        return this.foodCart.getState().items.length > 0;
      case 'grocery':
        return this.groceryCart(basket.storeType).getState().lines.length > 0;
      case 'pharmacy':
        return this.pharmacyCart.getState().items.length > 0;
    }
  }

  /** Ports `fillCart`: replaces the matching cart's contents with `basket` and returns that cart's route. */
  async fillCart(basket: ReorderBasket): Promise<string> {
    switch (basket.kind) {
      case 'food': {
        const cart = this.foodCart.getState();
        await cart.clear();
        for (const item of basket.items) {
          await this.foodCart.getState().addItem(item, { quantity: item.quantity });
        }
        return AppRoutes.foodCart;
      }
      case 'grocery': {
        const cart = this.groceryCart(basket.storeType);
        for (const line of [...cart.getState().lines]) {
          cart.getState().remove(line.product.id);
        }
        for (const { product, quantity } of basket.lines) {
          cart.getState().addProduct(product);
          // Falls back to one step when the past quantity isn't a valid
          // step of today's product (e.g. its step size changed).
          cart.getState().setQuantity(product.id, quantity);
        }
        return groceryCartRouteFor(basket.storeType);
      }
      case 'pharmacy': {
        this.pharmacyCart.getState().clearCart();
        for (const { product, quantity } of basket.lines) {
          this.pharmacyCart.getState().addProduct(product, { quantity });
        }
        return AppRoutes.pharmacyCart;
      }
    }
  }
}

/** Messages `runOrderAgain` shows -- mirrors the Dart snackbar/dialog copy exactly. */
export const ORDER_AGAIN_MESSAGES = {
  loadFailed: 'This order could not be loaded. Try again.',
  nothingAvailable: 'None of these items can be ordered right now.',
  replaceTitle: 'Replace your cart?',
  replaceBody: 'Your cart already has items. Ordering again will replace them.',
  skipped: (names: string[]) => `No longer available: ${names.join(', ')}`,
} as const;

export interface RunOrderAgainOptions {
  service: OrderAgainService;
  item: ActivityItem;
  /** Asks "Replace your cart?"; resolves `true` to replace, `false` to cancel. */
  confirmReplace: () => Promise<boolean>;
  /** Shows a short message (the Dart `showCartSnackBar`). */
  showMessage: (message: string) => void;
  /** Opens the filled cart (the Dart `context.go(cartRoute)`). */
  navigate: (route: string) => void;
}

export type RunOrderAgainResult = 'loadFailed' | 'nothingAvailable' | 'cancelled' | 'filled';

/**
 * Ports `TrackOrderScreen._orderAgainPressed`'s flow without its widgets:
 * load the basket; say so and stop if it couldn't load or nothing is
 * orderable any more; ask before replacing a non-empty cart; fill it, list
 * any skipped items, and open the cart.
 */
export async function runOrderAgain({ service, item, confirmReplace, showMessage, navigate }: RunOrderAgainOptions): Promise<RunOrderAgainResult> {
  let basket: ReorderBasket | null = null;
  try {
    basket = await service.loadBasket(item);
  } catch (error) {
    ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, 'TrackOrderScreen._orderAgainPressed');
  }

  if (basket == null) {
    showMessage(ORDER_AGAIN_MESSAGES.loadFailed);
    return 'loadFailed';
  }
  if (isReorderBasketEmpty(basket)) {
    showMessage(ORDER_AGAIN_MESSAGES.nothingAvailable);
    return 'nothingAvailable';
  }
  if (service.wouldReplaceCart(basket) && !(await confirmReplace())) {
    return 'cancelled';
  }

  const cartRoute = await service.fillCart(basket);
  if (basket.skippedNames.length > 0) {
    showMessage(ORDER_AGAIN_MESSAGES.skipped(basket.skippedNames));
  }
  navigate(cartRoute);
  return 'filled';
}
