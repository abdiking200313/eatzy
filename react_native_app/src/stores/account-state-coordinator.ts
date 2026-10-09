/**
 * Ports `flutter_app/lib/platform/session/account_state_coordinator.dart`
 * (issue #359).
 *
 * Clears account-scoped state when the authenticated owner changes, same
 * as the Flutter original, with one deliberate difference: Flutter's
 * coordinator directly resets `ActivityController` because activity history
 * is shared platform state with no RN port yet (it lands in a later issue).
 * This coordinator instead clears the shared TanStack Query cache
 * (`resetQueryCache`, defaulting to `queryClient.clear()`) as this app's
 * current platform-wide "shared, account-scoped in-memory state" -- any
 * per-user data fetched through `useQuery` is gone the moment the owner
 * changes, the same guarantee Flutter gets from clearing its activity
 * controller. A feature module (a cart store, ...) that needs its own
 * reset/reload behavior still registers with {@link SessionResetRegistry}
 * exactly as on the Flutter side, not by teaching this file about that
 * module.
 *
 * The Crashlytics user identifier update *is* ported one-for-one (issue
 * #351 landed `ErrorReporting`/`CrashlyticsErrorReporter` first): set to the
 * new owner id on sign-in, cleared (`null`) on sign-out, with no email or
 * name ever passed, exactly mirroring
 * `account_state_coordinator_test.dart`'s "Crashlytics user identifier"
 * group.
 */
import { queryClient as defaultQueryClient } from '@/platform/query/query-client';
import { CrashlyticsErrorReporter } from '@/platform/error-reporting/crashlytics-error-reporter';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

import { sessionResetRegistry, type SessionResetRegistry } from './session-reset-registry';

export interface AccountStateCoordinatorOptions {
  initialOwnerId?: string | null;
  registry?: SessionResetRegistry;
  /** Defaults to clearing the shared TanStack Query cache -- see this file's top comment. */
  resetQueryCache?: () => void;
}

export class AccountStateCoordinator {
  private ownerId: string | null;
  private readonly registry: SessionResetRegistry;
  private readonly resetQueryCache: () => void;

  constructor(options: AccountStateCoordinatorOptions = {}) {
    this.ownerId = options.initialOwnerId ?? null;
    this.registry = options.registry ?? sessionResetRegistry;
    this.resetQueryCache = options.resetQueryCache ?? (() => defaultQueryClient.clear());
  }

  getOwnerId(): string | null {
    return this.ownerId;
  }

  /**
   * Call on every auth-state event with the incoming owner id (`null` when
   * signed out). Returns `true` when the owner actually changed (and so
   * every registered reset ran); `false` when `nextOwnerId` matches the
   * current owner, so nothing was reset -- e.g. a token refresh for the
   * same signed-in user must not wipe that user's own cart/cache.
   */
  handleOwnerChanged(nextOwnerId: string | null): boolean {
    if (this.ownerId === nextOwnerId) {
      return false;
    }

    this.ownerId = nextOwnerId;
    this.resetQueryCache();
    this.registry.notifyAll(nextOwnerId);
    this.updateCrashlyticsUserIdentifier(nextOwnerId);
    return true;
  }

  private updateCrashlyticsUserIdentifier(ownerId: string | null): void {
    const reporter = ErrorReporting.instance;
    if (reporter instanceof CrashlyticsErrorReporter) {
      void reporter.setUserIdentifier(ownerId);
    }
  }
}
