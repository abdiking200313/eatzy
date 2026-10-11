/**
 * Ports `flutter_app/lib/features/merchant/store/presentation/merchant_store_controller.dart`
 * (issue #407 / P9-02): load/create/update bookkeeping for the "My Store"
 * screen, including the Dart `LoadableState`/`SavableState` mixins'
 * `isLoading`/`loadError`/`isSaving`/`saveError` fields.
 *
 * Like `profile-edit-controller.ts`, the Dart `ChangeNotifier` becomes a
 * plain class with `subscribe`/`getSnapshot`, read from React through
 * `useSyncExternalStore` ({@link useMerchantStoreState}) -- no new
 * state-management dependency, and the controller stays unit-testable
 * without rendering anything.
 */
import { useSyncExternalStore } from 'react';

import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

import type { MerchantStore } from './api/merchant-store';
import {
  SupabaseMerchantStoreRepository,
  type CreateMerchantStoreInput,
  type MerchantStoreRepository,
  type UpdateMerchantStoreInput,
} from './api/merchant-store-repository';

export const LOAD_FAILURE_MESSAGE = 'Your store could not be loaded. Please try again.';
export const CREATE_FAILURE_MESSAGE = 'Your store could not be created. Please try again.';
export const SAVE_FAILURE_MESSAGE = 'Your store could not be saved. Please try again.';

export interface MerchantStoreState {
  /** The merchant's own store, or `null` if not loaded yet, or loaded and the merchant has no store in any vertical. */
  store: MerchantStore | null;
  /** Whether {@link MerchantStoreController.load} has completed at least once, distinguishing "still loading" from the empty state. */
  hasLoaded: boolean;
  isLoading: boolean;
  loadError: string | null;
  isSaving: boolean;
  saveError: string | null;
}

const INITIAL_STATE: MerchantStoreState = {
  store: null,
  hasLoaded: false,
  isLoading: false,
  loadError: null,
  isSaving: false,
  saveError: null,
};

function report(error: unknown, context: string): void {
  ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, context);
}

export class MerchantStoreController {
  private readonly repository: MerchantStoreRepository;
  private state: MerchantStoreState = INITIAL_STATE;
  private readonly listeners = new Set<() => void>();

  constructor({ repository = new SupabaseMerchantStoreRepository() }: { repository?: MerchantStoreRepository } = {}) {
    this.repository = repository;
  }

  get store(): MerchantStore | null {
    return this.state.store;
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

  getSnapshot = (): MerchantStoreState => this.state;

  async load(ownerId: string): Promise<void> {
    this.setState({ isLoading: true, loadError: null });
    try {
      const store = await this.repository.fetchOwnStore(ownerId);
      this.setState({ store, hasLoaded: true, isLoading: false });
    } catch (error) {
      report(error, 'MerchantStoreController.load');
      this.setState({ isLoading: false, loadError: LOAD_FAILURE_MESSAGE });
    }
  }

  /** Creates a new store for the merchant, for the "no store yet" empty state. Resolves `true` on success. */
  createStore(input: CreateMerchantStoreInput): Promise<boolean> {
    return this.runSave(
      () => this.repository.createStore(input),
      'MerchantStoreController.createStore',
      CREATE_FAILURE_MESSAGE,
    );
  }

  /** Saves edits to the already-loaded store. Resolves `true` on success, `false` with no store loaded. */
  updateStore(input: UpdateMerchantStoreInput): Promise<boolean> {
    const currentStore = this.state.store;
    if (currentStore == null) return Promise.resolve(false);
    return this.runSave(
      () => this.repository.updateStore(currentStore, input),
      'MerchantStoreController.updateStore',
      SAVE_FAILURE_MESSAGE,
    );
  }

  private async runSave(mutate: () => Promise<MerchantStore>, context: string, failureMessage: string): Promise<boolean> {
    this.setState({ isSaving: true, saveError: null });
    try {
      const store = await mutate();
      this.setState({ store, isSaving: false });
      return true;
    } catch (error) {
      report(error, context);
      this.setState({ isSaving: false, saveError: failureMessage });
      return false;
    }
  }

  private setState(patch: Partial<MerchantStoreState>): void {
    this.state = { ...this.state, ...patch };
    for (const listener of this.listeners) listener();
  }
}

/** Subscribes a component to `controller`'s state -- the RN stand-in for the Dart screen's `addListener(setState)`. */
export function useMerchantStoreState(controller: MerchantStoreController): MerchantStoreState {
  return useSyncExternalStore(controller.subscribe, controller.getSnapshot, controller.getSnapshot);
}
