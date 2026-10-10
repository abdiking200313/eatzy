/**
 * Ports `flutter_app/test/profile_edit_controller_test.dart` (issue #400 /
 * P8-04), case for case.
 *
 * The Dart `updateEmail` cases build a real signed-in `AuthService` on a
 * mocked HTTP client because `AuthService` isn't an interface there; here
 * the controller depends on the narrow {@link ProfileEmailAuth} seam, so a
 * plain recording fake stands in. The "transport failure" case throws the
 * same `AuthRetryableFetchError` supabase-js raises for a network error.
 */
import { AuthRetryableFetchError } from '@supabase/supabase-js';

import { ErrorReporting, NoopErrorReporter } from '@/platform/error-reporting/error-reporter';

import type { CustomerProfile } from './api/customer-profile';
import type { ProfileRepository, ProfileUpdate } from './api/profile-repository';
import { ProfileEditController, type ProfileEmailAuth } from './profile-edit-controller';

class RecordingProfileRepository implements ProfileRepository {
  readonly updateCalls: ProfileUpdate[] = [];
  private readonly pending: (() => void)[] = [];

  constructor(private readonly options: { error?: unknown; delay?: boolean } = {}) {}

  completeDelayed(): void {
    for (const complete of this.pending.splice(0)) complete();
  }

  async fetchCurrentProfile(): Promise<CustomerProfile | null> {
    throw new Error('not exercised by this test');
  }

  async updateProfile(update: ProfileUpdate): Promise<CustomerProfile> {
    if (this.options.delay) {
      await new Promise<void>((resolve) => this.pending.push(resolve));
    }
    this.updateCalls.push(update);
    if (this.options.error !== undefined) throw this.options.error;
    return {
      id: 'customer-1',
      firstName: update.firstName ?? 'Amina',
      lastName: update.lastName ?? 'Noor',
      phone: update.phone ?? '+252 61 234 5678',
      avatarUrl: null,
      dob: update.dob ?? null,
    };
  }

  async deleteAccount(): Promise<void> {
    throw new Error('not exercised by this test');
  }
}

class FakeEmailAuth implements ProfileEmailAuth {
  readonly updateEmailCalls: string[] = [];

  constructor(
    private readonly currentEmail: string | null,
    private readonly error?: unknown,
  ) {}

  getCurrentUserEmail(): string | null {
    return this.currentEmail;
  }

  async updateEmail(email: string): Promise<void> {
    this.updateEmailCalls.push(email);
    if (this.error !== undefined) throw this.error;
  }
}

const originalReporter = ErrorReporting.instance;

beforeEach(() => {
  ErrorReporting.instance = new NoopErrorReporter();
});

afterEach(() => {
  ErrorReporting.instance = originalReporter;
});

describe('ProfileEditController.updateName', () => {
  test('rejects an empty first name without calling the repository', async () => {
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updateName({ firstName: '  ', lastName: 'Noor' });

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain('Enter your first name.');
    expect(controller.fieldErrors).toContain('Enter your first name.');
    expect(repository.updateCalls).toHaveLength(0);
    expect(controller.isSubmitting).toBe(false);
  });

  test('rejects an empty last name without calling the repository', async () => {
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updateName({ firstName: 'Amina', lastName: '' });

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain('Enter your last name.');
    expect(repository.updateCalls).toHaveLength(0);
  });

  test('trims and forwards only first/last name to the repository, returning its saved profile', async () => {
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updateName({ firstName: '  Amina  ', lastName: ' Noor ' });

    expect(result.isSuccess).toBe(true);
    expect(result.profile?.firstName).toBe('Amina');
    expect(controller.isSubmitting).toBe(false);
    expect(controller.submissionError).toBeNull();
    // Phone/dob were not part of this call, so they must stay unsent
    // rather than sent as null-that-means-clear.
    expect(repository.updateCalls).toEqual([{ firstName: 'Amina', lastName: 'Noor' }]);
  });

  test('surfaces a generic message when the repository throws', async () => {
    const repository = new RecordingProfileRepository({ error: new Error('network down') });
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updateName({ firstName: 'Amina', lastName: 'Noor' });

    expect(result.isSuccess).toBe(false);
    expect(controller.isSubmitting).toBe(false);
    expect(controller.submissionError).toBe('Could not save your profile. Please try again.');
  });

  test('a second call while one is in flight is a no-op', async () => {
    const repository = new RecordingProfileRepository({ delay: true });
    const controller = new ProfileEditController({ profileRepository: repository });

    const first = controller.updateName({ firstName: 'Amina', lastName: 'Noor' });
    const second = await controller.updateName({ firstName: 'Amina', lastName: 'Noor' });

    expect(second.isSuccess).toBe(false);
    expect(second.errors).toHaveLength(0);
    repository.completeDelayed();
    const firstResult = await first;
    expect(firstResult.isSuccess).toBe(true);
    expect(repository.updateCalls).toHaveLength(1);
  });
});

describe('ProfileEditController.updatePhone', () => {
  test('rejects an empty phone number without calling the repository', async () => {
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updatePhone('   ');

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain('Enter your phone number.');
    expect(repository.updateCalls).toHaveLength(0);
  });

  test('rejects an implausibly short phone number without calling the repository', async () => {
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updatePhone('123');

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain('Please enter a valid phone number.');
    expect(repository.updateCalls).toHaveLength(0);
  });

  test('trims and forwards only the phone number to the repository, returning its saved profile', async () => {
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updatePhone(' +252 61 234 5678 ');

    expect(result.isSuccess).toBe(true);
    expect(repository.updateCalls).toEqual([{ phone: '+252 61 234 5678' }]);
  });

  test('surfaces a generic message when the repository throws', async () => {
    const repository = new RecordingProfileRepository({ error: new Error('network down') });
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updatePhone('+252 61 234 5678');

    expect(result.isSuccess).toBe(false);
    expect(controller.submissionError).toBe('Could not save your profile. Please try again.');
  });
});

describe('ProfileEditController.updateDob', () => {
  test('rejects a date of birth in the future without calling the repository', async () => {
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository });
    const future = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const result = await controller.updateDob(future);

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain("Date of birth can't be in the future.");
    expect(repository.updateCalls).toHaveLength(0);
  });

  test('forwards only the date of birth to the repository, returning its saved profile', async () => {
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository });
    const dob = new Date(1995, 5, 15);

    const result = await controller.updateDob(dob);

    expect(result.isSuccess).toBe(true);
    expect(repository.updateCalls).toEqual([{ dob }]);
  });

  test('surfaces a generic message when the repository throws', async () => {
    const repository = new RecordingProfileRepository({ error: new Error('network down') });
    const controller = new ProfileEditController({ profileRepository: repository });

    const result = await controller.updateDob(new Date(1995, 5, 15));

    expect(result.isSuccess).toBe(false);
    expect(controller.submissionError).toBe('Could not save your profile. Please try again.');
  });
});

describe('ProfileEditController.updateEmail', () => {
  test('rejects an empty email without calling AuthService', async () => {
    const emailAuth = new FakeEmailAuth('amina@zivo.app');
    const controller = new ProfileEditController({
      profileRepository: new RecordingProfileRepository(),
      emailAuth,
    });

    const result = await controller.updateEmail('   ');

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain('Enter your email address.');
    expect(emailAuth.updateEmailCalls).toHaveLength(0);
  });

  test('rejects an invalid email format without calling AuthService', async () => {
    const emailAuth = new FakeEmailAuth('amina@zivo.app');
    const controller = new ProfileEditController({
      profileRepository: new RecordingProfileRepository(),
      emailAuth,
    });

    const result = await controller.updateEmail('not-an-email');

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain('Please enter a valid email address.');
    expect(emailAuth.updateEmailCalls).toHaveLength(0);
  });

  test('rejects the unchanged email address (case-insensitively) without calling AuthService.updateEmail', async () => {
    const emailAuth = new FakeEmailAuth('amina@zivo.app');
    const controller = new ProfileEditController({
      profileRepository: new RecordingProfileRepository(),
      emailAuth,
    });

    const result = await controller.updateEmail('AMINA@ZIVO.APP');

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain("That's already your email address.");
    expect(emailAuth.updateEmailCalls).toHaveLength(0);
  });

  test('trims and calls AuthService.updateEmail, returning success with no profile and without touching the profile repository', async () => {
    const emailAuth = new FakeEmailAuth('amina@zivo.app');
    const repository = new RecordingProfileRepository();
    const controller = new ProfileEditController({ profileRepository: repository, emailAuth });

    const result = await controller.updateEmail('  new@zivo.app  ');

    expect(result.isSuccess).toBe(true);
    expect(result.profile).toBeNull();
    expect(repository.updateCalls).toHaveLength(0);
    expect(emailAuth.updateEmailCalls).toEqual(['new@zivo.app']);
  });

  test('maps a thrown error to a generic user-facing message', async () => {
    const emailAuth = new FakeEmailAuth('amina@zivo.app', new AuthRetryableFetchError('network down', 0));
    const controller = new ProfileEditController({
      profileRepository: new RecordingProfileRepository(),
      emailAuth,
    });

    const result = await controller.updateEmail('new@zivo.app');

    expect(result.isSuccess).toBe(false);
    expect(result.errors).toContain('We could not complete that request. Please try again.');
    expect(controller.isSubmitting).toBe(false);
  });

  test('a second call while one is in flight is a no-op', async () => {
    const emailAuth = new FakeEmailAuth('amina@zivo.app');
    const controller = new ProfileEditController({
      profileRepository: new RecordingProfileRepository(),
      emailAuth,
    });

    const first = controller.updateEmail('new@zivo.app');
    const second = await controller.updateEmail('new@zivo.app');

    expect(second.isSuccess).toBe(false);
    expect(second.errors).toHaveLength(0);
    const firstResult = await first;
    expect(firstResult.isSuccess).toBe(true);
    expect(emailAuth.updateEmailCalls).toHaveLength(1);
  });

  test('throws when no emailAuth was provided, instead of falling back to a real client', async () => {
    const controller = new ProfileEditController({ profileRepository: new RecordingProfileRepository() });

    await expect(controller.updateEmail('new@zivo.app')).rejects.toThrow(/requires an emailAuth/);
  });
});

describe('ProfileEditController subscriptions', () => {
  test('notifies subscribers on every state change and stops after unsubscribe', async () => {
    const controller = new ProfileEditController({ profileRepository: new RecordingProfileRepository() });
    const listener = jest.fn();
    const unsubscribe = controller.subscribe(listener);

    await controller.updatePhone('');
    expect(listener).toHaveBeenCalledTimes(1);
    expect(controller.getSnapshot().fieldErrors).toEqual(['Enter your phone number.']);

    unsubscribe();
    await controller.updatePhone('+252 61 234 5678');
    expect(listener).toHaveBeenCalledTimes(1);
  });
});
