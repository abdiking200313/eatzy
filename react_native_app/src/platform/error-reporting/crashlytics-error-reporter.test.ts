/// Ports `flutter_app/test/crashlytics_error_reporter_test.dart` (issue #351).
import { CrashlyticsErrorReporter, type CrashlyticsClient } from './crashlytics-error-reporter';

interface RecordedCall {
  error: unknown;
  stack: string | undefined;
  fatal: boolean;
  reason: string | undefined;
}

class FakeCrashlyticsClient implements CrashlyticsClient {
  readonly recorded: RecordedCall[] = [];
  readonly userIdentifiers: string[] = [];
  collectionEnabled: boolean | undefined;

  async recordError(
    error: unknown,
    stack: string | undefined,
    { fatal = false, reason }: { fatal?: boolean; reason?: string } = {},
  ): Promise<void> {
    this.recorded.push({ error, stack, fatal, reason });
  }

  async setUserIdentifier(identifier: string): Promise<void> {
    this.userIdentifiers.push(identifier);
  }

  async setCrashlyticsCollectionEnabled(enabled: boolean): Promise<void> {
    this.collectionEnabled = enabled;
  }
}

describe('CrashlyticsErrorReporter', () => {
  let client: FakeCrashlyticsClient;
  let reporter: CrashlyticsErrorReporter;

  beforeEach(() => {
    client = new FakeCrashlyticsClient();
    reporter = new CrashlyticsErrorReporter(client);
  });

  for (const context of CrashlyticsErrorReporter.globalHookContexts) {
    it(`reports "${context}" (a global error hook) as fatal`, async () => {
      const error = new Error('boom');
      const stack = error.stack;

      reporter.reportError(error, stack, context);
      // recordError is fire-and-forget (see reportError's doc comment);
      // flush the microtask queue so the fake has recorded the call before
      // asserting on it.
      await Promise.resolve();

      expect(client.recorded).toHaveLength(1);
      expect(client.recorded[0]).toEqual({ error, stack, fatal: true, reason: context });
    });
  }

  it('reports a caught call site (not a global hook) as non-fatal', async () => {
    const error = new Error('boom');
    const stack = error.stack;

    reporter.reportError(error, stack, 'ProfileScreen.loadProfile');
    await Promise.resolve();

    expect(client.recorded).toHaveLength(1);
    expect(client.recorded[0].fatal).toBe(false);
    expect(client.recorded[0].reason).toBe('ProfileScreen.loadProfile');
  });

  it('reports with no context as non-fatal', async () => {
    reporter.reportError(new Error('boom'));
    await Promise.resolve();

    expect(client.recorded).toHaveLength(1);
    expect(client.recorded[0].fatal).toBe(false);
    expect(client.recorded[0].reason).toBeUndefined();
  });

  it('setUserIdentifier forwards the user id, and clears it with an empty string when null/undefined (sign-out)', async () => {
    await reporter.setUserIdentifier('user-123');
    expect(client.userIdentifiers).toEqual(['user-123']);

    await reporter.setUserIdentifier(null);
    expect(client.userIdentifiers).toEqual(['user-123', '']);
  });
});
