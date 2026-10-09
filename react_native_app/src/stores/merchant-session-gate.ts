/**
 * Ports `flutter_app/lib/app/merchant_session_gate.dart` (issue #363).
 *
 * `(auth)/_layout.tsx` and `(app)/_layout.tsx` need this decision
 * synchronously on every navigation (via `resolveRedirect`'s `isMerchant`
 * parameter), but the underlying `profiles.role` lookup
 * (`MerchantRoleService.fetchRole`) is async. {@link resolveFor} does that
 * lookup once per signed-in user and caches the answer in this store, so a
 * `merchant`/`admin` account's role is known *before* a login-dependent
 * redirect decision runs -- the three layouts treat a signed-in user whose
 * role is still unresolved the same way they already treat `status ===
 * 'loading'` (see `(auth)/_layout.tsx`'s doc comment), so a freshly
 * signed-in merchant/admin is never bounced through the customer home while
 * the role lookup is still in flight.
 *
 * Unlike Flutter's `MerchantSessionGate` (a bag of static fields updated by
 * explicit `AppRouter` call sites), this is wired to the same "account
 * changed" signal `AccountStateCoordinator`/`SessionResetRegistry` already
 * broadcast for every other account-scoped reset (`account-state-
 * coordinator.ts`'s top comment) -- registering a callback with
 * `sessionResetRegistry` right here, the same way a cart store would, is
 * what starts the lookup on sign-in/session-restore and clears it on
 * sign-out, instead of a second independent `onAuthStateChange`
 * subscription or an explicit call from the layouts themselves.
 */
import { create, type StoreApi, type UseBoundStore } from 'zustand';

import {
  isAuthorizedMerchantRole,
  MerchantRoleService,
} from '@/platform/navigation/merchant-role-service';

import { sessionResetRegistry, type SessionResetRegistry } from './session-reset-registry';

/** How long the role lookup may run before the account is treated as a plain customer (the same fail-closed answer a failed lookup gives). */
export const MERCHANT_ROLE_LOOKUP_TIMEOUT_MS = 15_000;

export interface MerchantSessionGateState {
  /**
   * The user id {@link isMerchantRole}/{@link isAdmin} were resolved for, or
   * `null` if nothing has been resolved this session (or it was just
   * cleared by {@link reset}). A signed-in `userId` that does not match
   * this means the role is still unknown for the current user -- callers
   * must wait rather than read `isMerchantRole`/`isAdmin` as a stale
   * answer.
   */
  resolvedUserId: string | null;
  /** Whether `resolvedUserId`'s account is `merchant`/`admin`. `false` until resolved, and reset to `false` on sign-out. */
  isMerchantRole: boolean;
  /**
   * Whether `resolvedUserId`'s account is specifically `admin` (a strict
   * subset of `isMerchantRole`), set alongside it. This is only a UI
   * convenience -- the actual authorization is enforced server-side by the
   * `admin_list_profiles`/`admin_set_profile_role` RPCs, not by this flag.
   */
  isAdmin: boolean;
}

/** The slice of `MerchantRoleService` {@link resolveFor} depends on -- lets a test inject a fake instead of a real one. */
export interface RoleLookup {
  fetchRole(userId: string): Promise<string | null>;
}

export interface CreateMerchantSessionGateOptions {
  /** Defaults to a real `MerchantRoleService` (the live `profiles` table). */
  roleService?: RoleLookup;
  /** Defaults to the shared `sessionResetRegistry` singleton -- pass a fresh one in a test to avoid sharing state with other tests/modules. */
  registry?: SessionResetRegistry;
  /** Defaults to {@link MERCHANT_ROLE_LOOKUP_TIMEOUT_MS}. */
  roleLookupTimeoutMs?: number;
}

export interface MerchantSessionGateHandle {
  store: UseBoundStore<StoreApi<MerchantSessionGateState>>;
  /**
   * Looks up `userId`'s `profiles.role` and caches it in the store. Returns
   * immediately if that user is already resolved, and joins an already-
   * running lookup for the same user rather than starting a second one. A
   * failed or timed-out lookup resolves to a plain customer, like
   * `MerchantRoleService.fetchRole` itself.
   */
  resolveFor: (userId: string, options?: { roleService?: RoleLookup }) => Promise<void>;
  /** Clears everything (call on sign-out), so the next sign-in/session-restore starts from a fresh lookup rather than a stale cached role. */
  reset: () => void;
  /** Stops listening for account changes. Mainly for tests -- the app-wide singleton below lives for the app's lifetime. */
  unregister: () => void;
}

/** Races `promise` against a `ms`-long timeout that resolves to `null` (the fail-closed answer) -- does not swallow a rejection from `promise` itself. */
function withTimeout(promise: Promise<string | null>, ms: number): Promise<string | null> {
  let timer: ReturnType<typeof setTimeout>;
  const timeout = new Promise<string | null>((resolve) => {
    timer = setTimeout(() => resolve(null), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

/**
 * Builds an independent merchant-session gate wired to `options.registry`
 * (the shared `sessionResetRegistry` by default). Exists mainly so a test
 * can build an isolated instance instead of sharing the app-wide singleton
 * -- see {@link useMerchantSessionGateStore} for the one the app actually
 * renders against.
 */
export function createMerchantSessionGate(
  options: CreateMerchantSessionGateOptions = {},
): MerchantSessionGateHandle {
  const defaultRoleService = options.roleService ?? new MerchantRoleService();
  const registry = options.registry ?? sessionResetRegistry;
  const timeoutMs = options.roleLookupTimeoutMs ?? MERCHANT_ROLE_LOOKUP_TIMEOUT_MS;

  const store = create<MerchantSessionGateState>(() => ({
    resolvedUserId: null,
    isMerchantRole: false,
    isAdmin: false,
  }));

  // Bumped by `reset` so a lookup that was already running when the user
  // signed out cannot write its result over the cleared state.
  let generation = 0;
  let inFlightUserId: string | null = null;
  let inFlight: Promise<void> | null = null;

  function resolveFor(
    userId: string,
    resolveOptions: { roleService?: RoleLookup } = {},
  ): Promise<void> {
    if (store.getState().resolvedUserId === userId) {
      return Promise.resolve();
    }
    if (inFlightUserId === userId && inFlight != null) {
      return inFlight;
    }

    const roleService = resolveOptions.roleService ?? defaultRoleService;
    const currentGeneration = generation;

    const lookup = (async () => {
      const role = await withTimeout(roleService.fetchRole(userId), timeoutMs);
      if (currentGeneration !== generation) {
        // Signed out (or resolved for yet another user) while this lookup
        // was in flight -- do not repopulate state `reset` already cleared.
        return;
      }
      store.setState({
        resolvedUserId: userId,
        isMerchantRole: isAuthorizedMerchantRole(role),
        isAdmin: role === 'admin',
      });
    })();

    inFlightUserId = userId;
    inFlight = lookup;
    return lookup.finally(() => {
      if (inFlight === lookup) {
        inFlight = null;
        inFlightUserId = null;
      }
    });
  }

  function reset(): void {
    generation++;
    inFlight = null;
    inFlightUserId = null;
    store.setState({ resolvedUserId: null, isMerchantRole: false, isAdmin: false });
  }

  // Runs on every account change (`AccountStateCoordinator.handleOwnerChanged`
  // -> `registry.notifyAll`), in lockstep with the session store's own
  // `status`/`userId` update -- see this file's top comment.
  const unregister = registry.register((nextOwnerId) => {
    if (nextOwnerId == null) {
      reset();
    } else {
      void resolveFor(nextOwnerId);
    }
  });

  return { store, resolveFor, reset, unregister };
}

const defaultMerchantSessionGate = createMerchantSessionGate();

/**
 * The app-wide merchant-session gate store. Read it the way any Zustand
 * store is read, e.g. `useMerchantSessionGateStore((state) =>
 * state.isMerchantRole)`.
 */
export const useMerchantSessionGateStore = defaultMerchantSessionGate.store;

/** Exposed for the rare direct (non-React) caller -- most code should just read {@link useMerchantSessionGateStore}. */
export const merchantSessionGate = defaultMerchantSessionGate;
