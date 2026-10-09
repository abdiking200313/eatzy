/**
 * Ports `flutter_app/lib/platform/session/session_reset_registry.dart`
 * (issue #359).
 *
 * Lets a feature module (a cart store, a cached list, ...) participate in
 * account-change session resets without this shared platform layer
 * importing anything service-specific. A module registers a reset callback
 * here -- typically right where it creates its own store/singleton -- and
 * {@link AccountStateCoordinator} (`account-state-coordinator.ts`) calls
 * every registered callback whenever the signed-in account changes.
 */

/**
 * Invoked when the authenticated account changes, so a feature module can
 * clear its own account-scoped in-memory state and, where relevant, reload
 * state persisted for the incoming `nextOwnerId` (or the guest owner, when
 * `null`).
 */
export type SessionResetCallback = (nextOwnerId: string | null) => void;

export class SessionResetRegistry {
  private callbacks: SessionResetCallback[] = [];

  /**
   * Registers `callback` to run on every account change. Returns a function
   * that removes the registration again -- mainly useful for tests, since
   * app-wide store singletons live for the app's lifetime.
   */
  register(callback: SessionResetCallback): () => void {
    this.callbacks.push(callback);
    return () => {
      this.callbacks = this.callbacks.filter((registered) => registered !== callback);
    };
  }

  /**
   * Runs every registered callback with the incoming `nextOwnerId`.
   * Callbacks are copied first so a callback that registers or removes
   * another during the call can't disturb this pass.
   */
  notifyAll(nextOwnerId: string | null): void {
    for (const callback of [...this.callbacks]) {
      callback(nextOwnerId);
    }
  }

  /** Test-only: removes every registered callback. */
  clearForTest(): void {
    this.callbacks = [];
  }
}

/**
 * The registry feature modules register into and that
 * {@link AccountStateCoordinator} listens to by default in production.
 */
export const sessionResetRegistry = new SessionResetRegistry();
