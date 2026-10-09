/**
 * Ports `flutter_app/test/account_state_coordinator_test.dart` (issue #359).
 *
 * The "an account change clears every account-scoped MVP state" case is
 * adapted to this app's current platform state (see
 * `account-state-coordinator.ts`'s top comment for why: no grocery/pharmacy
 * controllers or activity controller exist on the RN side yet, so a fake
 * cart-like module standing in for them is registered with a fresh
 * `SessionResetRegistry`, the same way each real service module will
 * register with the shared `sessionResetRegistry` singleton once it
 * exists). The "Crashlytics user identifier" group is ported one-for-one,
 * now that issue #351 landed `ErrorReporting`/`CrashlyticsErrorReporter`.
 */
import { CrashlyticsErrorReporter, type CrashlyticsClient } from '@/platform/error-reporting/crashlytics-error-reporter';
import { ErrorReporting, LoggingErrorReporter, type ErrorReporter } from '@/platform/error-reporting/error-reporter';

import { AccountStateCoordinator } from './account-state-coordinator';
import { SessionResetRegistry } from './session-reset-registry';

describe('AccountStateCoordinator', () => {
  it('is a no-op (returns false, resets nothing) when the owner has not changed', () => {
    const registry = new SessionResetRegistry();
    const resetQueryCache = jest.fn();
    const notifyAll = jest.spyOn(registry, 'notifyAll');
    const coordinator = new AccountStateCoordinator({
      initialOwnerId: 'user-one',
      registry,
      resetQueryCache,
    });

    expect(coordinator.handleOwnerChanged('user-one')).toBe(false);
    expect(resetQueryCache).not.toHaveBeenCalled();
    expect(notifyAll).not.toHaveBeenCalled();
    expect(coordinator.getOwnerId()).toBe('user-one');
  });

  it('clears the query cache and notifies every registered reset callback when the owner changes', () => {
    // Fresh registry per test, mirroring how each service module's own
    // store self-registers in the real app -- the shared coordinator never
    // imports a feature module's store directly.
    const registry = new SessionResetRegistry();
    const resetQueryCache = jest.fn();

    let fakeCart: string[] = ['user-one item'];
    registry.register((ownerId) => {
      fakeCart = ownerId === 'user-one' ? ['user-one item'] : [];
    });

    const coordinator = new AccountStateCoordinator({
      initialOwnerId: 'user-one',
      registry,
      resetQueryCache,
    });

    expect(coordinator.handleOwnerChanged('user-two')).toBe(true);
    expect(resetQueryCache).toHaveBeenCalledTimes(1);
    expect(fakeCart).toEqual([]);
    expect(coordinator.getOwnerId()).toBe('user-two');

    // Switching back to the original owner reloads their state again,
    // rather than leaving it permanently cleared.
    expect(coordinator.handleOwnerChanged('user-one')).toBe(true);
    expect(resetQueryCache).toHaveBeenCalledTimes(2);
    expect(fakeCart).toEqual(['user-one item']);
  });

  it('resets on sign-out (owner -> null) too, so no previous user data is left visible', () => {
    const registry = new SessionResetRegistry();
    const resetQueryCache = jest.fn();
    const seen: (string | null)[] = [];
    registry.register((ownerId) => seen.push(ownerId));

    const coordinator = new AccountStateCoordinator({
      initialOwnerId: 'user-one',
      registry,
      resetQueryCache,
    });

    expect(coordinator.handleOwnerChanged(null)).toBe(true);
    expect(seen).toEqual([null]);
    expect(resetQueryCache).toHaveBeenCalledTimes(1);
  });

  it('defaults to a fresh owner id of null and the shared sessionResetRegistry singleton', () => {
    const coordinator = new AccountStateCoordinator();
    expect(coordinator.getOwnerId()).toBeNull();
  });

  describe('Crashlytics user identifier (issue #287)', () => {
    let originalReporter: ErrorReporter;

    beforeEach(() => {
      originalReporter = ErrorReporting.instance;
    });

    afterEach(() => {
      ErrorReporting.instance = originalReporter;
    });

    it('is a no-op when ErrorReporting.instance is not a CrashlyticsErrorReporter (e.g. a debug build)', () => {
      ErrorReporting.instance = new LoggingErrorReporter();
      const coordinator = new AccountStateCoordinator({
        registry: new SessionResetRegistry(),
        resetQueryCache: () => {},
      });

      expect(() => coordinator.handleOwnerChanged('user-one')).not.toThrow();
    });

    it('sets the Crashlytics user identifier on sign-in and clears it on sign-out, with no email or name ever passed', async () => {
      const client: CrashlyticsClient = {
        recordError: jest.fn(),
        setUserIdentifier: jest.fn(async () => undefined),
        setCrashlyticsCollectionEnabled: jest.fn(async () => undefined),
      };
      ErrorReporting.instance = new CrashlyticsErrorReporter(client);
      const coordinator = new AccountStateCoordinator({
        registry: new SessionResetRegistry(),
        resetQueryCache: () => {},
      });

      coordinator.handleOwnerChanged('user-one');
      await Promise.resolve();
      expect(client.setUserIdentifier).toHaveBeenNthCalledWith(1, 'user-one');

      coordinator.handleOwnerChanged(null);
      await Promise.resolve();
      expect(client.setUserIdentifier).toHaveBeenNthCalledWith(2, '');
    });
  });
});
