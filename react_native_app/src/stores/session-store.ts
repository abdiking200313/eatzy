/**
 * The Zustand session store (issue #359), fed by
 * `supabase.auth.onAuthStateChange` -- the RN equivalent of
 * `app_router.dart`'s `_AuthStateRefresh` (which exists purely to make
 * GoRouter re-run its redirect on every auth event) combined with
 * `main.dart`'s own `onAuthStateChange` subscription that drives
 * `AccountStateCoordinator`. Both land here: every auth event updates this
 * store's state (read by `src/app/(auth)/_layout.tsx` and
 * `src/app/(app)/_layout.tsx` to decide whether to redirect) *and* runs
 * {@link AccountStateCoordinator.handleOwnerChanged}, so a feature module's
 * registered {@link SessionResetRegistry} callback always fires in lockstep
 * with the state those layouts render against.
 */
import { create, type StoreApi, type UseBoundStore } from 'zustand';
import type { AuthChangeEvent, Session } from '@supabase/supabase-js';

import { supabase } from '@/platform/supabase/client';

import { AccountStateCoordinator, type AccountStateCoordinatorOptions } from './account-state-coordinator';

export type SessionStatus = 'loading' | 'signedIn' | 'signedOut';

export interface SessionState {
  /**
   * `'loading'` until the first auth event (Supabase's own synthetic
   * `INITIAL_SESSION` event, fired once restoring from storage finishes)
   * resolves whether a session exists. Callers that redirect on
   * `status !== 'signedIn'` should wait out `'loading'` first -- see this
   * file's top comment and #360 (startup gate), which holds the splash
   * screen on exactly this.
   */
  status: SessionStatus;
  session: Session | null;
  /** `session?.user.id`, kept alongside `session` so callers that only care about identity don't need to reach into `session` themselves. */
  userId: string | null;
}

/**
 * The slice of `supabase.auth` this store depends on, narrowed the same way
 * `secure-session-storage.ts`/`fake-supabase-client.ts` narrow their own
 * Supabase dependencies -- lets a test inject a fake instead of the real
 * client.
 */
export interface AuthStateSource {
  onAuthStateChange(
    callback: (event: AuthChangeEvent, session: Session | null) => void,
  ): { data: { subscription: { unsubscribe(): void } } };
}

export interface CreateSessionStoreOptions {
  auth?: AuthStateSource;
  coordinatorOptions?: AccountStateCoordinatorOptions;
}

export interface SessionStoreHandle {
  store: UseBoundStore<StoreApi<SessionState>>;
  coordinator: AccountStateCoordinator;
  /** Stops listening to auth events. Mainly for tests -- the app-wide singleton below lives for the app's lifetime. */
  unsubscribe: () => void;
}

/**
 * Builds an independent session store wired to `options.auth` (the real
 * `supabase.auth` by default). Exists mainly so a test can build an
 * isolated instance with a fake auth source instead of sharing the
 * app-wide singleton -- see {@link useSessionStore} for the one the app
 * actually renders against.
 */
export function createSessionStore(options: CreateSessionStoreOptions = {}): SessionStoreHandle {
  const auth = options.auth ?? supabase.auth;
  const coordinator = new AccountStateCoordinator(options.coordinatorOptions);

  const store = create<SessionState>(() => ({
    status: 'loading',
    session: null,
    userId: null,
  }));

  const { data } = auth.onAuthStateChange((_event, session) => {
    const nextOwnerId = session?.user.id ?? null;
    // Runs every registered reset callback (cart stores, caches, ...) when
    // -- and only when -- the owner actually changed, so e.g. a token
    // refresh for the same signed-in user never wipes that user's own
    // state.
    coordinator.handleOwnerChanged(nextOwnerId);
    store.setState({
      status: nextOwnerId != null ? 'signedIn' : 'signedOut',
      session,
      userId: nextOwnerId,
    });
  });

  return {
    store,
    coordinator,
    unsubscribe: () => data.subscription.unsubscribe(),
  };
}

const defaultSessionStore = createSessionStore();

/**
 * The app-wide session store. Read it the way any Zustand store is read,
 * e.g. `useSessionStore((state) => state.status)`.
 */
export const useSessionStore = defaultSessionStore.store;
