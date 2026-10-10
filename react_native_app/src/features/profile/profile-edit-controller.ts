/**
 * Ports `flutter_app/lib/features/profile/presentation/profile_edit_controller.dart`
 * (issue #400 / P8-04): owns profile-edit form state (validation,
 * submission, success/error) for the Settings → Account edit sheets (Name /
 * Phone / Date of birth / Email).
 *
 * The Dart `ChangeNotifier` becomes a plain class with `subscribe`/
 * `getSnapshot`, read from React through `useSyncExternalStore` (see
 * {@link useProfileEditState}) -- no new state-management dependency, and
 * the controller stays unit-testable without rendering anything.
 */
import { useSyncExternalStore } from 'react';

import { describeAuthError } from '@/features/auth/api/auth-error-message';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';

import type { CustomerProfile } from './api/customer-profile';
import type { ProfileRepository } from './api/profile-repository';
import {
  validateDob,
  validateEmail,
  validateFirstName,
  validateLastName,
  validatePhone,
} from './profile-field-validators';

/**
 * Mirrors `ProfileEditResult`. `profile` is the saved row for the
 * `updateName`/`updatePhone`/`updateDob` calls; it is always `null` for
 * `updateEmail`, whose success means only that Supabase accepted the change
 * request -- the new address isn't live until the confirmation link is
 * tapped.
 */
export interface ProfileEditResult {
  isSuccess: boolean;
  profile: CustomerProfile | null;
  errors: readonly string[];
}

function success(profile: CustomerProfile | null = null): ProfileEditResult {
  return { isSuccess: true, profile, errors: [] };
}

function invalid(errors: readonly string[]): ProfileEditResult {
  return { isSuccess: false, profile: null, errors: Object.freeze([...errors]) };
}

/**
 * The slice of auth `updateEmail` needs. Dart reads the current email off
 * `AuthService.getCurrentUserEmail` (the SDK's synchronous
 * `currentSession`); `@supabase/supabase-js` has no synchronous session
 * getter, so the Settings screen supplies it from the session store instead.
 */
export interface ProfileEmailAuth {
  getCurrentUserEmail(): string | null;
  updateEmail(email: string): Promise<unknown>;
}

export interface ProfileEditState {
  isSubmitting: boolean;
  submissionError: string | null;
  /** Validation messages for the current attempt, mapped onto fields by the presentation layer. */
  fieldErrors: readonly string[];
}

export const SAVE_FAILURE_MESSAGE = 'Could not save your profile. Please try again.';

const INITIAL_STATE: ProfileEditState = { isSubmitting: false, submissionError: null, fieldErrors: [] };

export interface ProfileEditControllerOptions {
  profileRepository: ProfileRepository;
  /** Optional, like the Dart `authService`: only {@link ProfileEditController.updateEmail} needs it, and it throws without one. */
  emailAuth?: ProfileEmailAuth;
}

export class ProfileEditController {
  private readonly repository: ProfileRepository;
  private readonly emailAuth: ProfileEmailAuth | undefined;
  private state: ProfileEditState = INITIAL_STATE;
  private readonly listeners = new Set<() => void>();

  constructor(options: ProfileEditControllerOptions) {
    this.repository = options.profileRepository;
    this.emailAuth = options.emailAuth;
  }

  get isSubmitting(): boolean {
    return this.state.isSubmitting;
  }

  get submissionError(): string | null {
    return this.state.submissionError;
  }

  get fieldErrors(): readonly string[] {
    return this.state.fieldErrors;
  }

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  getSnapshot = (): ProfileEditState => this.state;

  /** Validates `firstName`/`lastName` and, if valid, writes them (trimmed) to the signed-in user's own profile. */
  async updateName({ firstName, lastName }: { firstName: string; lastName: string }): Promise<ProfileEditResult> {
    const errors = [validateFirstName(firstName), validateLastName(lastName)].filter(
      (error): error is string => error != null,
    );
    if (errors.length > 0) return this.invalid(errors);
    return this.run(() =>
      this.repository.updateProfile({ firstName: firstName.trim(), lastName: lastName.trim() }),
    );
  }

  /** Validates `phone` and, if valid, writes it (trimmed) to the signed-in user's own profile. */
  async updatePhone(phone: string): Promise<ProfileEditResult> {
    const error = validatePhone(phone);
    if (error != null) return this.invalid([error]);
    return this.run(() => this.repository.updateProfile({ phone: phone.trim() }));
  }

  /** Validates `dob` and, if valid, writes it to the signed-in user's own profile. */
  async updateDob(dob: Date): Promise<ProfileEditResult> {
    const error = validateDob(dob);
    if (error != null) return this.invalid([error]);
    return this.run(() => this.repository.updateProfile({ dob }));
  }

  /**
   * Validates `email` and, if it differs (case-insensitively) from the
   * signed-in user's current address, starts an email change. Success
   * carries no profile -- see {@link ProfileEditResult}.
   */
  async updateEmail(email: string): Promise<ProfileEditResult> {
    const error = validateEmail(email);
    if (error != null) return this.invalid([error]);

    const auth = this.requireEmailAuth();
    const trimmed = email.trim();
    const currentEmail = auth.getCurrentUserEmail();
    if (currentEmail != null && currentEmail.toLowerCase() === trimmed.toLowerCase()) {
      return this.invalid(["That's already your email address."]);
    }

    if (this.state.isSubmitting) return invalid([]);

    this.beginSubmit();
    try {
      await auth.updateEmail(trimmed);
      this.endSubmit(null);
      return success();
    } catch (caught) {
      ErrorReporting.instance.reportError(
        caught,
        caught instanceof Error ? caught.stack : undefined,
        'ProfileEditController.updateEmail',
      );
      const message = describeAuthError(caught, 'Email update');
      this.endSubmit(message);
      return invalid([message]);
    }
  }

  private requireEmailAuth(): ProfileEmailAuth {
    if (this.emailAuth == null) {
      throw new Error(
        'ProfileEditController.updateEmail requires an emailAuth; none was provided to this controller.',
      );
    }
    return this.emailAuth;
  }

  private invalid(errors: readonly string[]): ProfileEditResult {
    this.setState({ ...this.state, fieldErrors: errors, submissionError: null });
    return invalid(errors);
  }

  /** Shared submit/error/double-submit-guard plumbing for the `profiles`-backed updates. */
  private async run(write: () => Promise<CustomerProfile>): Promise<ProfileEditResult> {
    if (this.state.isSubmitting) return invalid([]);

    this.beginSubmit();
    try {
      const profile = await write();
      this.endSubmit(null);
      return success(profile);
    } catch (caught) {
      ErrorReporting.instance.reportError(
        caught,
        caught instanceof Error ? caught.stack : undefined,
        'ProfileEditController.submit',
      );
      this.endSubmit(SAVE_FAILURE_MESSAGE);
      return invalid([SAVE_FAILURE_MESSAGE]);
    }
  }

  private beginSubmit(): void {
    this.setState({ isSubmitting: true, submissionError: null, fieldErrors: [] });
  }

  private endSubmit(error: string | null): void {
    this.setState({ ...this.state, isSubmitting: false, submissionError: error });
  }

  private setState(next: ProfileEditState): void {
    this.state = next;
    for (const listener of this.listeners) listener();
  }
}

/** Subscribes a component to `controller`'s state -- the RN stand-in for the Dart sheet's `AnimatedBuilder(animation: controller)`. */
export function useProfileEditState(controller: ProfileEditController): ProfileEditState {
  return useSyncExternalStore(controller.subscribe, controller.getSnapshot, controller.getSnapshot);
}
