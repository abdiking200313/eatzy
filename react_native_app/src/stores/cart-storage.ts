/**
 * Ports `flutter_app/lib/services/shared/data/cart_storage.dart` (issue
 * #376): the generic, per-module/per-owner persistence abstraction every
 * vertical's cart store (`food-cart-store.ts`, `grocery-cart-store.ts`,
 * `pharmacy-cart-store.ts`) is built on.
 *
 * Mirrors the Dart file's three pieces:
 * - {@link CartStorage} / {@link AsyncStorageCartStorage} -- the Dart
 *   `CartStorage<T>` / `SharedPreferencesCartStorage<T>` pair. Values are
 *   scoped by both a per-module `keyPrefix` (so the food/grocery/pharmacy
 *   carts, and grocery's per-`GroceryStoreType` variants, never collide) and
 *   `ownerId` (so switching accounts -- or signing out -- never leaks one
 *   owner's cart into another's). `@react-native-async-storage/
 *   async-storage` is this app's direct analogue of
 *   `SharedPreferencesAsync`: unencrypted, local-only key/value storage,
 *   which is all a cart (no credentials, nothing sensitive) needs -- see
 *   `onboarding-preferences.ts`'s doc comment for the same reasoning applied
 *   to another non-sensitive local flag.
 * - {@link readCartLogged} -- unchanged in spirit from the Dart function of
 *   the same name: reports (rather than silently discarding) an exception
 *   `CartStorage.read` itself lets through, substituting an empty cart, so
 *   "no saved cart" and "cart failed to load" both resolve the same way for
 *   callers while staying distinguishable in error reports.
 * - {@link CartWriteQueue} -- unchanged in spirit from the Dart class:
 *   serializes one controller's persistence writes so overlapping cart
 *   mutations don't race each other, while guaranteeing a failed write is
 *   neither an unhandled rejection nor silently invisible.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

/**
 * A per-module, per-owner keyed store for a list of cart-like items of type
 * `T`. See this file's top comment.
 */
export interface CartStorage<T> {
  read(ownerId: string): Promise<T[]>;
  write(ownerId: string, items: T[]): Promise<void>;
  clear(ownerId: string): Promise<void>;
}

/** The slice of `@react-native-async-storage/async-storage`'s API this module depends on -- lets a test inject an in-memory fake instead of the real native module. */
export interface KeyValueStore {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
}

const defaultKeyValueStore: KeyValueStore = {
  getItem: (key) => AsyncStorage.getItem(key),
  setItem: (key, value) => AsyncStorage.setItem(key, value),
  removeItem: (key) => AsyncStorage.removeItem(key),
};

export interface AsyncStorageCartStorageOptions<T> {
  /**
   * Must be unique per module (e.g. one value for the food cart, another
   * for each grocery `GroceryStoreType`, another for the pharmacy cart) so
   * the same owner's carts across verticals never collide or overwrite one
   * another.
   */
  keyPrefix: string;
  toJson: (item: T) => unknown;
  fromJson: (json: Record<string, unknown>) => T;
  /** Defaults to the real `AsyncStorage`. Injectable for tests. */
  store?: KeyValueStore;
}

/**
 * A {@link CartStorage} backed by `AsyncStorage`, serialized as JSON under
 * the key `${keyPrefix}.${ownerId}` -- the RN counterpart of Dart's
 * `SharedPreferencesCartStorage<T>`.
 */
export class AsyncStorageCartStorage<T> implements CartStorage<T> {
  private readonly keyPrefix: string;
  private readonly toJsonFn: (item: T) => unknown;
  private readonly fromJsonFn: (json: Record<string, unknown>) => T;
  private readonly store: KeyValueStore;

  constructor(options: AsyncStorageCartStorageOptions<T>) {
    this.keyPrefix = options.keyPrefix;
    this.toJsonFn = options.toJson;
    this.fromJsonFn = options.fromJson;
    this.store = options.store ?? defaultKeyValueStore;
  }

  private keyFor(ownerId: string): string {
    return `${this.keyPrefix}.${ownerId}`;
  }

  async read(ownerId: string): Promise<T[]> {
    const key = this.keyFor(ownerId);
    const raw = await this.store.getItem(key);
    if (raw == null || raw === '') {
      return [];
    }

    try {
      const decoded = JSON.parse(raw);
      if (!Array.isArray(decoded)) {
        throw new Error('Cart data must be a list');
      }
      return decoded.map((item) => this.fromJsonFn(item as Record<string, unknown>));
    } catch (error) {
      // A broken local value should not make the cart screen unusable, but
      // it must not silently present as "no saved cart" either -- a saved
      // value existed here and failed to parse, which is a materially
      // different situation from there being nothing to load.
      ErrorReporting.instance.reportError(
        error,
        error instanceof Error ? error.stack : undefined,
        'AsyncStorageCartStorage.read',
      );
      await this.store.removeItem(key);
      return [];
    }
  }

  async write(ownerId: string, items: T[]): Promise<void> {
    await this.store.setItem(this.keyFor(ownerId), JSON.stringify(items.map((item) => this.toJsonFn(item))));
  }

  async clear(ownerId: string): Promise<void> {
    await this.store.removeItem(this.keyFor(ownerId));
  }
}

/**
 * Reads `ownerId`'s cart from `storage`, logging (rather than silently
 * discarding) any exception {@link CartStorage.read} itself lets through and
 * substituting an empty cart so callers can keep treating "no cart" and
 * "cart failed to load" the same way at the UI layer.
 *
 * `AsyncStorageCartStorage.read` already recovers from a corrupted stored
 * value on its own (logging as it does so) and only ever resolves normally,
 * so this mainly guards against the storage layer itself throwing. Either
 * way, the resulting log line is explicitly distinguishable from "there was
 * no saved cart for this owner" -- that case returns an empty array without
 * going through this catch at all, so it is never logged as a failure.
 *
 * `label` identifies the calling store/vertical (e.g. `'GroceryCartStore'`)
 * so a failure can be traced back to which cart it came from.
 */
export async function readCartLogged<T>(storage: CartStorage<T>, ownerId: string, label: string): Promise<T[]> {
  try {
    return await storage.read(ownerId);
  } catch (error) {
    ErrorReporting.instance.reportError(
      error,
      error instanceof Error ? error.stack : undefined,
      `${label}.loadForOwner`,
    );
    return [];
  }
}

/**
 * Serializes cart persistence writes for one store so overlapping cart
 * mutations don't race each other, while guaranteeing a failed write is
 * neither an unhandled rejection nor silently invisible.
 *
 * Shared by the food, grocery, and pharmacy cart stores so each one gets the
 * same guarantee instead of maintaining its own copy of this queuing logic.
 */
export class CartWriteQueue {
  /** Identifies the owning store/vertical (e.g. `'FoodCartStore'`, `'GroceryCartStore'`, `'PharmacyCartStore'`) in failure logs. */
  private readonly label: string;
  private pendingWrite: Promise<void> = Promise.resolve();

  constructor(label: string) {
    this.label = label;
  }

  /** The in-flight (or, once settled, most recently finished) queued write. Exposed primarily so tests can await outstanding cart persistence before asserting on stored state. */
  get pending(): Promise<void> {
    return this.pendingWrite;
  }

  /**
   * Queues `write` behind whatever write is currently pending. A later
   * write always gets its turn -- an earlier write failing does not block
   * it -- and a failure from `write` itself is logged rather than left to
   * become an unhandled rejection or propagate to the caller.
   */
  enqueue(write: () => Promise<void>): Promise<void> {
    const previousWrite = this.pendingWrite;
    const operation = (async () => {
      try {
        await previousWrite;
      } catch {
        // A later cart change should still get a chance to persist.
      }
      try {
        await write();
      } catch (error) {
        ErrorReporting.instance.reportError(
          error,
          error instanceof Error ? error.stack : undefined,
          `${this.label}.enqueue`,
        );
      }
    })();
    this.pendingWrite = operation;
    return operation;
  }
}

/** The owner key used for a signed-out (guest) cart -- mirrors Dart's `_guestOwner = 'guest'`, shared by every vertical's cart store. */
export const GUEST_CART_OWNER = 'guest';
