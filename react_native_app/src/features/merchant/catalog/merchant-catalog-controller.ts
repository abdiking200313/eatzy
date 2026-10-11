/**
 * Ports `flutter_app/lib/features/merchant/catalog/presentation/merchant_catalog_controller.dart`
 * (issue #410 / P9-05): load / create / update / delete / toggle-availability
 * bookkeeping for the merchant "Catalog" screen, including the Dart
 * `LoadableState`/`SavableState` mixins' `isLoading`/`loadError`/
 * `isSaving`/`saveError` fields.
 *
 * Same shape as `merchant-store-controller.ts`: the Dart `ChangeNotifier`
 * becomes a plain class with `subscribe`/`getSnapshot`, read from React via
 * `useSyncExternalStore` ({@link useMerchantCatalogState}).
 */
import { useSyncExternalStore } from 'react';

import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

import type { MerchantVertical } from '../store/api/merchant-vertical';
import type { MerchantCatalogItem, PharmacyCategory } from './api/merchant-catalog-item';
import { SupabaseMerchantCatalogRepository, type MerchantCatalogRepository } from './api/merchant-catalog-repository';

export const CATALOG_LOAD_FAILURE_MESSAGE = 'Your catalog could not be loaded. Please try again.';
export const CATALOG_CREATE_FAILURE_MESSAGE = 'The item could not be added. Please try again.';
export const CATALOG_SAVE_FAILURE_MESSAGE = 'The item could not be saved. Please try again.';
export const CATALOG_DELETE_FAILURE_MESSAGE = 'The item could not be deleted. Please try again.';
export const CATALOG_AVAILABILITY_FAILURE_MESSAGE = 'Availability could not be updated. Please try again.';

export interface MerchantCatalogState {
  /** Sorted by name, like the Dart controller after every mutation. */
  items: readonly MerchantCatalogItem[];
  pharmacyCategories: readonly PharmacyCategory[];
  /** Whether {@link MerchantCatalogController.load} has completed at least once -- distinguishes "still loading" from a genuinely empty catalog. */
  hasLoaded: boolean;
  isLoading: boolean;
  loadError: string | null;
  isSaving: boolean;
  saveError: string | null;
}

const INITIAL_STATE: MerchantCatalogState = {
  items: [],
  pharmacyCategories: [],
  hasLoaded: false,
  isLoading: false,
  loadError: null,
  isSaving: false,
  saveError: null,
};

function report(error: unknown, context: string): void {
  ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, context);
}

/** Dart's `a.name.compareTo(b.name)` -- a plain code-unit comparison, not locale-aware. */
function byName(a: MerchantCatalogItem, b: MerchantCatalogItem): number {
  if (a.name < b.name) return -1;
  if (a.name > b.name) return 1;
  return 0;
}

export class MerchantCatalogController {
  readonly vertical: MerchantVertical;
  readonly storeId: string;
  private readonly repository: MerchantCatalogRepository;
  private state: MerchantCatalogState = INITIAL_STATE;
  private readonly listeners = new Set<() => void>();

  constructor({
    vertical,
    storeId,
    repository = new SupabaseMerchantCatalogRepository(),
  }: {
    vertical: MerchantVertical;
    storeId: string;
    repository?: MerchantCatalogRepository;
  }) {
    this.vertical = vertical;
    this.storeId = storeId;
    this.repository = repository;
  }

  get items(): readonly MerchantCatalogItem[] {
    return this.state.items;
  }
  get pharmacyCategories(): readonly PharmacyCategory[] {
    return this.state.pharmacyCategories;
  }
  get hasLoaded(): boolean {
    return this.state.hasLoaded;
  }
  get isLoading(): boolean {
    return this.state.isLoading;
  }
  get loadError(): string | null {
    return this.state.loadError;
  }
  get isSaving(): boolean {
    return this.state.isSaving;
  }
  get saveError(): string | null {
    return this.state.saveError;
  }

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  getSnapshot = (): MerchantCatalogState => this.state;

  async load(): Promise<void> {
    this.setState({ isLoading: true, loadError: null });
    try {
      const [items, pharmacyCategories] = await Promise.all([
        this.repository.fetchItems({ vertical: this.vertical, storeId: this.storeId }),
        this.vertical === 'pharmacy' ? this.repository.fetchPharmacyCategories() : Promise.resolve(this.state.pharmacyCategories),
      ]);
      this.setState({ items: [...items], pharmacyCategories: [...pharmacyCategories], hasLoaded: true, isLoading: false });
    } catch (error) {
      report(error, 'MerchantCatalogController.load');
      this.setState({ isLoading: false, loadError: CATALOG_LOAD_FAILURE_MESSAGE });
    }
  }

  /** Resolves `true` on success. */
  createItem(draft: MerchantCatalogItem): Promise<boolean> {
    return this.runSave(
      async () => {
        const created = await this.repository.createItem(draft);
        return [...this.state.items, created].sort(byName);
      },
      'MerchantCatalogController.createItem',
      CATALOG_CREATE_FAILURE_MESSAGE,
    );
  }

  /** Resolves `true` on success. */
  updateItem(item: MerchantCatalogItem): Promise<boolean> {
    return this.runSave(
      async () => {
        const updated = await this.repository.updateItem(item);
        const items = [...this.state.items];
        const index = items.findIndex((existing) => existing.id === item.id);
        if (index === -1) items.push(updated);
        else items[index] = updated;
        return items.sort(byName);
      },
      'MerchantCatalogController.updateItem',
      CATALOG_SAVE_FAILURE_MESSAGE,
    );
  }

  /** Resolves `true` on success. */
  deleteItem(item: MerchantCatalogItem): Promise<boolean> {
    return this.runSave(
      async () => {
        await this.repository.deleteItem(item);
        return this.state.items.filter((existing) => existing.id !== item.id);
      },
      'MerchantCatalogController.deleteItem',
      CATALOG_DELETE_FAILURE_MESSAGE,
    );
  }

  /** Flips `item.isAvailable`. Resolves `true` on success. */
  toggleAvailability(item: MerchantCatalogItem): Promise<boolean> {
    const isAvailable = !item.isAvailable;
    return this.runSave(
      async () => {
        const updated = await this.repository.setAvailability({ item, isAvailable });
        return this.state.items.map((existing) => (existing.id === item.id ? updated : existing));
      },
      'MerchantCatalogController.toggleAvailability',
      CATALOG_AVAILABILITY_FAILURE_MESSAGE,
    );
  }

  private async runSave(
    mutate: () => Promise<MerchantCatalogItem[]>,
    context: string,
    failureMessage: string,
  ): Promise<boolean> {
    this.setState({ isSaving: true, saveError: null });
    try {
      const items = await mutate();
      this.setState({ items, isSaving: false });
      return true;
    } catch (error) {
      report(error, context);
      this.setState({ isSaving: false, saveError: failureMessage });
      return false;
    }
  }

  private setState(patch: Partial<MerchantCatalogState>): void {
    this.state = { ...this.state, ...patch };
    for (const listener of this.listeners) listener();
  }
}

/** Subscribes a component to `controller`'s state. */
export function useMerchantCatalogState(controller: MerchantCatalogController): MerchantCatalogState {
  return useSyncExternalStore(controller.subscribe, controller.getSnapshot, controller.getSnapshot);
}
