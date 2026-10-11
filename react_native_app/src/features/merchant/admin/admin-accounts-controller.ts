/**
 * Ports `flutter_app/lib/features/merchant/admin/presentation/admin_accounts_controller.dart`
 * (issue #412 / P9-07): list/search/paging/role-change bookkeeping for the
 * admin-only "Accounts" screen, including the Dart `SavableState` mixin's
 * `isSaving`/`saveError` fields.
 *
 * Like `MerchantStoreController`, the Dart `ChangeNotifier` becomes a plain
 * class with `subscribe`/`getSnapshot`, read from React through
 * `useSyncExternalStore` ({@link useAdminAccountsState}).
 *
 * As in Dart, the list's loading state is tracked with a generation counter
 * rather than a simple "isLoading" toggle: search results arrive out of
 * order as the admin types, and a stale, slower response must not clear
 * `isLoading` (or set an error) while a newer search is still in flight.
 */
import { useSyncExternalStore } from 'react';

import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

import type { AdminAccount } from './api/admin-account';
import { AdminAccountsError, SupabaseAdminAccountsRepository, type AdminAccountsRepository } from './api/admin-accounts-repository';

/** Accounts fetched per page (the Dart `pageSize`). */
export const ADMIN_ACCOUNTS_PAGE_SIZE = 25;

export const LOAD_FAILURE_MESSAGE = 'The accounts could not be loaded. Please try again.';
export const LOAD_MORE_FAILURE_MESSAGE = 'More accounts could not be loaded. Please try again.';
export const SET_ROLE_FAILURE_MESSAGE = 'The role could not be changed. Please try again.';

export interface AdminAccountsState {
  /** The accounts loaded so far for the current `query`, newest first. */
  accounts: readonly AdminAccount[];
  /** The trimmed search text the current `accounts` were loaded for. */
  query: string;
  /** Whether another page is available from `loadMore`. */
  hasMore: boolean;
  /** Whether a first-page `load` is in flight. */
  isLoading: boolean;
  /** Whether a `loadMore` page fetch is in flight. */
  isLoadingMore: boolean;
  loadError: string | null;
  loadMoreError: string | null;
  /** The id of the account whose role change is in flight, or `null`. */
  savingId: string | null;
  isSaving: boolean;
  saveError: string | null;
}

const INITIAL_STATE: AdminAccountsState = {
  accounts: [],
  query: '',
  hasMore: false,
  isLoading: false,
  isLoadingMore: false,
  loadError: null,
  loadMoreError: null,
  savingId: null,
  isSaving: false,
  saveError: null,
};

function report(error: unknown, context: string): void {
  ErrorReporting.instance.reportError(error, error instanceof Error ? error.stack : undefined, context);
}

function messageFor(error: unknown, fallback: string): string {
  return error instanceof AdminAccountsError ? error.message : fallback;
}

export class AdminAccountsController {
  private readonly repository: AdminAccountsRepository;
  private state: AdminAccountsState = INITIAL_STATE;
  private readonly listeners = new Set<() => void>();
  /** Bumped by every `load`; a response tagged with an older id is discarded. */
  private generation = 0;

  constructor({ repository = new SupabaseAdminAccountsRepository() }: { repository?: AdminAccountsRepository } = {}) {
    this.repository = repository;
  }

  get accounts(): readonly AdminAccount[] {
    return this.state.accounts;
  }
  get query(): string {
    return this.state.query;
  }
  get hasMore(): boolean {
    return this.state.hasMore;
  }
  get isLoading(): boolean {
    return this.state.isLoading;
  }
  get isLoadingMore(): boolean {
    return this.state.isLoadingMore;
  }
  get loadError(): string | null {
    return this.state.loadError;
  }
  get loadMoreError(): string | null {
    return this.state.loadMoreError;
  }
  get savingId(): string | null {
    return this.state.savingId;
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

  getSnapshot = (): AdminAccountsState => this.state;

  /**
   * Loads the first page of accounts matching `query` (all accounts when
   * empty), replacing whatever was loaded before. Any older in-flight
   * `load`/`loadMore` response is discarded.
   */
  async load(query = ''): Promise<void> {
    const generation = ++this.generation;
    const trimmed = query.trim();
    this.setState({ query: trimmed, isLoading: true, isLoadingMore: false, loadError: null, loadMoreError: null });

    try {
      const rows = await this.repository.listAccounts({ search: trimmed, limit: ADMIN_ACCOUNTS_PAGE_SIZE + 1, offset: 0 });
      if (generation !== this.generation) return;
      this.setState({
        accounts: rows.slice(0, ADMIN_ACCOUNTS_PAGE_SIZE),
        hasMore: rows.length > ADMIN_ACCOUNTS_PAGE_SIZE,
        isLoading: false,
      });
    } catch (error) {
      if (generation !== this.generation) return;
      report(error, 'AdminAccountsController.load');
      this.setState({ accounts: [], hasMore: false, isLoading: false, loadError: messageFor(error, LOAD_FAILURE_MESSAGE) });
    }
  }

  /** Appends the next page for the current `query`. No-op when there is nothing more to load or a fetch is already running. */
  async loadMore(): Promise<void> {
    if (!this.state.hasMore || this.state.isLoading || this.state.isLoadingMore) return;
    const generation = this.generation;
    this.setState({ isLoadingMore: true, loadMoreError: null });

    try {
      const rows = await this.repository.listAccounts({
        search: this.state.query,
        limit: ADMIN_ACCOUNTS_PAGE_SIZE + 1,
        offset: this.state.accounts.length,
      });
      if (generation !== this.generation) return;
      this.setState({
        accounts: [...this.state.accounts, ...rows.slice(0, ADMIN_ACCOUNTS_PAGE_SIZE)],
        hasMore: rows.length > ADMIN_ACCOUNTS_PAGE_SIZE,
        isLoadingMore: false,
      });
    } catch (error) {
      if (generation !== this.generation) return;
      report(error, 'AdminAccountsController.loadMore');
      this.setState({ isLoadingMore: false, loadMoreError: messageFor(error, LOAD_MORE_FAILURE_MESSAGE) });
    }
  }

  /**
   * Sets account `profileId`'s role to `newRole`. Resolves `false` (no-op) if
   * that account isn't currently loaded, or if the server rejects the change
   * (see `saveError`); on success the loaded account reflects the new role
   * without a re-fetch.
   */
  async setRole(profileId: string, newRole: string): Promise<boolean> {
    if (!this.state.accounts.some((account) => account.id === profileId)) return false;
    this.setState({ savingId: profileId, isSaving: true, saveError: null });
    try {
      await this.repository.setRole({ profileId, newRole });
      this.setState({
        accounts: this.state.accounts.map((account) => (account.id === profileId ? { ...account, role: newRole } : account)),
        savingId: null,
        isSaving: false,
      });
      return true;
    } catch (error) {
      report(error, 'AdminAccountsController.setRole');
      this.setState({ savingId: null, isSaving: false, saveError: messageFor(error, SET_ROLE_FAILURE_MESSAGE) });
      return false;
    }
  }

  private setState(patch: Partial<AdminAccountsState>): void {
    this.state = { ...this.state, ...patch };
    for (const listener of this.listeners) listener();
  }
}

/** Subscribes a component to `controller`'s state -- the RN stand-in for the Dart screen's `ListenableBuilder`. */
export function useAdminAccountsState(controller: AdminAccountsController): AdminAccountsState {
  return useSyncExternalStore(controller.subscribe, controller.getSnapshot, controller.getSnapshot);
}
