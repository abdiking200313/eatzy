import { zodResolver } from '@hookform/resolvers/zod';
import { MaterialIcons } from '@expo/vector-icons';
import DateTimePicker, { type DateTimePickerEvent } from '@react-native-community/datetimepicker';
import { router } from 'expo-router';
import { useState } from 'react';
import { Controller, useForm, type FieldErrors } from 'react-hook-form';
import { ActivityIndicator, Alert, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { z } from 'zod';

import { AppTextField } from '@/components/app-text-field';
import { AuthCard } from '@/components/auth-card';
import { AuthPageBackground } from '@/components/auth-page-background';
import { GradientActionButton } from '@/components/gradient-action-button';
import { ZivoLogo } from '@/components/zivo-logo';
import { describeAuthError } from '@/features/auth/api/auth-error-message';
import { authService } from '@/features/auth/api/auth-service';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { formatShortDate } from '@/platform/localization/date-format';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { rawColors, spacing } from '@/theme/tokens';

// Ports flutter_app/lib/features/auth/presentation/register_screen.dart's
// `RegisterScreen` (issue #366). New accounts are always plain `customer`
// role (the `profiles` table's own default) -- unlike `login.tsx`, there is
// no merchant-redirect decision to make after a successful sign-up.
//
// Every client-side validation rule below is a direct 1:1 port of
// `_RegisterScreenState._register`'s sequence of early-return `if`s, folded
// into one `superRefine` so exactly one combined message is ever shown per
// submit attempt (never Zod's usual per-field messages) -- same posture
// `login.tsx`'s own schema doc comment describes, generalized from one rule
// to this screen's ordered checklist. Order matters: the first rule that
// fails is the only message shown, exactly matching the Dart method's
// early-return order.
const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+\-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$/;
const PHONE_REGEX = /^\+?[0-9\s-]{7,15}$/;

const registerFormSchema = z
  .object({
    firstName: z.string(),
    lastName: z.string(),
    phone: z.string(),
    dob: z.date().nullable(),
    email: z.string(),
    password: z.string(),
    confirmPassword: z.string(),
  })
  .superRefine((values, ctx) => {
    const firstName = values.firstName.trim();
    const lastName = values.lastName.trim();
    const phone = values.phone.trim();
    const email = values.email.trim();
    const { dob, password, confirmPassword } = values;

    if (
      firstName.length === 0 ||
      lastName.length === 0 ||
      phone.length === 0 ||
      dob == null ||
      email.length === 0 ||
      password.length === 0 ||
      confirmPassword.length === 0
    ) {
      ctx.addIssue({ code: 'custom', message: 'Please fill in every field.', path: ['form'] });
      return;
    }
    if (password.length < 6) {
      ctx.addIssue({ code: 'custom', message: 'Password must be at least 6 characters.', path: ['form'] });
      return;
    }
    if (!EMAIL_REGEX.test(email)) {
      ctx.addIssue({ code: 'custom', message: 'Please enter a valid email address.', path: ['form'] });
      return;
    }
    if (!PHONE_REGEX.test(phone)) {
      ctx.addIssue({ code: 'custom', message: 'Please enter a valid phone number.', path: ['form'] });
      return;
    }
    if (password !== confirmPassword) {
      ctx.addIssue({ code: 'custom', message: 'Passwords do not match.', path: ['form'] });
    }
  });

type RegisterFormValues = z.infer<typeof registerFormSchema>;

/** Mirrors `_pickDob`'s `initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day)`. */
function eighteenYearsAgo(): Date {
  const now = new Date();
  return new Date(now.getFullYear() - 18, now.getMonth(), now.getDate());
}

export default function RegisterScreen() {
  const colors = useSemanticColors();
  const [message, setMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isDobPickerVisible, setIsDobPickerVisible] = useState(false);

  const { control, handleSubmit } = useForm<RegisterFormValues>({
    resolver: zodResolver(registerFormSchema),
    defaultValues: {
      firstName: '',
      lastName: '',
      phone: '',
      dob: null,
      email: '',
      password: '',
      confirmPassword: '',
    },
  });

  // Mirrors `_register`: the sign-up call sits in its own try/catch, but the
  // post-success session-vs-no-session branch (and the dialog/navigation it
  // triggers) sits outside it -- a failure there must never be reported as
  // a sign-up failure. See `login.tsx`'s own doc comment and the Dart file's
  // issue #295 comment for the same invariant on the sign-in side.
  const onValid = async (values: RegisterFormValues) => {
    setMessage(null);
    setIsLoading(true);
    let response: { user: { id: string } | null; session: unknown | null };
    try {
      response = await authService.signUpWithEmailPassword(values.email.trim(), values.password, {
        firstName: values.firstName.trim(),
        lastName: values.lastName.trim(),
        phone: values.phone.trim(),
        // Non-null: the schema's `superRefine` already rejected a missing
        // `dob` before `handleSubmit` ever calls this function.
        dob: values.dob!,
      });
    } catch (error) {
      setMessage(`Registration failed: ${describeAuthError(error, 'Registration')}`);
      return;
    } finally {
      setIsLoading(false);
    }

    if (response.session != null) {
      router.replace(AppRoutes.mainApp);
      return;
    }

    const email = values.email.trim();
    // RN has no built-in `AlertDialog` equivalent to Flutter's
    // `showDialog`/`AlertDialog` -- this app has no richer modal component
    // yet either (checked `src/components/**`), so the platform `Alert.alert`
    // API stands in for it: a non-dismissible (`cancelable: false`, mirroring
    // `barrierDismissible: false`) title/message/single-button dialog.
    Alert.alert(
      'Confirm your email',
      `We sent a confirmation link to ${email}. Open the link to activate your account, then sign in.`,
      [{ text: 'Go to sign in', onPress: () => router.replace(AppRoutes.login) }],
      { cancelable: false },
    );
  };

  // Mirrors the single combined message `_register`'s early-return `if`s
  // show via `_showMessage` -- see this file's top comment.
  const onInvalid = (errors: FieldErrors<RegisterFormValues>) => {
    const formError = (errors as Record<string, { message?: string } | undefined>).form;
    setMessage(formError?.message ?? 'Please fill in every field.');
  };

  const submit = handleSubmit(onValid, onInvalid);

  // Fire-and-forget, mirroring the Dart screen's own un-awaited
  // `onPressed: _register` -- but reports (rather than silently swallows) a
  // rejection, the same departure `login.tsx`'s own doc comment explains in
  // full for its sibling `handlePress`.
  const handlePress = () => {
    submit().catch((error: unknown) => {
      ErrorReporting.instance.reportError(
        error,
        error instanceof Error ? error.stack : undefined,
        'RegisterScreen.handlePress',
      );
    });
  };

  const handleBack = () => {
    if (router.canGoBack()) {
      router.back();
    } else {
      router.replace(AppRoutes.welcomeRevisit);
    }
  };

  return (
    <AuthPageBackground>
      <SafeAreaView edges={['top', 'bottom']} className="flex-1">
        <ScrollView contentContainerStyle={{ padding: spacing.x5 }} keyboardShouldPersistTaps="handled">
          <View className="w-full items-center self-center" style={{ maxWidth: 460 }}>
            <View className="w-full flex-row">
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Back"
                onPress={handleBack}
                style={{ backgroundColor: rawColors.white, width: 44, height: 44, borderRadius: 22 }}
                className="items-center justify-center active:opacity-70">
                <MaterialIcons name="arrow-back" size={22} color={colors.text} />
              </Pressable>
            </View>
            <View style={{ height: spacing.x4 }} />
            <ZivoLogo height={44} />
            <View style={{ height: spacing.x6 }} />

            <AuthCard>
              <Text className="text-text3xl font-outfitBold text-text">Create your account</Text>
              <View style={{ height: spacing.x2 }} />
              <Text className="text-textSm font-outfitRegular text-textMuted">
                Join Zivo to order food, groceries and more, delivered to you.
              </Text>
              <View style={{ height: spacing.sectionGap }} />

              {message && (
                <>
                  <Text accessibilityRole="alert" className="text-textSm font-outfitMedium text-error">
                    {message}
                  </Text>
                  <View style={{ height: spacing.x3 }} />
                </>
              )}

              <Controller
                control={control}
                name="firstName"
                render={({ field: { value, onChange } }) => (
                  <AppTextField
                    label="First name"
                    hint="Jane"
                    value={value}
                    onChangeText={onChange}
                    prefixIcon="person-outline"
                    textInputAction="next"
                    autoComplete="given-name"
                  />
                )}
              />
              <View style={{ height: spacing.x3_5 }} />
              <Controller
                control={control}
                name="lastName"
                render={({ field: { value, onChange } }) => (
                  <AppTextField
                    label="Last name"
                    hint="Doe"
                    value={value}
                    onChangeText={onChange}
                    prefixIcon="person-outline"
                    textInputAction="next"
                    autoComplete="family-name"
                  />
                )}
              />
              <View style={{ height: spacing.x3_5 }} />
              <Controller
                control={control}
                name="phone"
                render={({ field: { value, onChange } }) => (
                  <AppTextField
                    label="Phone number"
                    hint="+1 555 123 4567"
                    value={value}
                    onChangeText={onChange}
                    keyboardType="phone-pad"
                    prefixIcon="phone"
                    textInputAction="next"
                    autoComplete="tel"
                  />
                )}
              />
              <View style={{ height: spacing.x3_5 }} />
              <Controller
                control={control}
                name="dob"
                render={({ field: { value, onChange } }) => (
                  <>
                    <AppTextField
                      label="Date of birth"
                      hint="Select your date of birth"
                      value={value ? formatShortDate(value) : ''}
                      prefixIcon="cake"
                      readOnly
                      onPress={() => setIsDobPickerVisible(true)}
                    />
                    {isDobPickerVisible && (
                      <DateTimePicker
                        value={value ?? eighteenYearsAgo()}
                        mode="date"
                        display="default"
                        maximumDate={new Date()}
                        // Mirrors `_pickDob`'s accept/cancel handling: a
                        // 'dismissed' event (or any call with no
                        // `selectedDate`) leaves the previously-picked value
                        // alone, exactly like `showDatePicker` returning
                        // `null` on cancel.
                        onChange={(_event: DateTimePickerEvent, selectedDate?: Date) => {
                          setIsDobPickerVisible(false);
                          if (selectedDate) {
                            onChange(selectedDate);
                          }
                        }}
                      />
                    )}
                  </>
                )}
              />
              <View style={{ height: spacing.x3_5 }} />
              <Controller
                control={control}
                name="email"
                render={({ field: { value, onChange } }) => (
                  <AppTextField
                    label="Email address"
                    hint="you@example.com"
                    value={value}
                    onChangeText={onChange}
                    keyboardType="email-address"
                    prefixIcon="mail-outline"
                    textInputAction="next"
                    autoComplete="email"
                  />
                )}
              />
              <View style={{ height: spacing.x3_5 }} />
              <Controller
                control={control}
                name="password"
                render={({ field: { value, onChange } }) => (
                  <AppTextField
                    label="Password"
                    hint="At least 6 characters"
                    value={value}
                    onChangeText={onChange}
                    prefixIcon="lock-outline"
                    obscureText
                    textInputAction="next"
                    autoComplete="password-new"
                  />
                )}
              />
              <View style={{ height: spacing.x3_5 }} />
              <Controller
                control={control}
                name="confirmPassword"
                render={({ field: { value, onChange } }) => (
                  <AppTextField
                    label="Confirm password"
                    hint="Enter the password again"
                    value={value}
                    onChangeText={onChange}
                    prefixIcon="verified-user"
                    obscureText
                    textInputAction="done"
                    onSubmitted={() => {
                      if (!isLoading) handlePress();
                    }}
                  />
                )}
              />
              <View style={{ height: spacing.x3_5 }} />
              <View className="flex-row items-start">
                <MaterialIcons name="shield" size={16} color={colors.primary} style={{ marginTop: 2 }} />
                <View style={{ width: spacing.x2 }} />
                <Text className="flex-1 text-textXs font-outfitRegular text-textMuted">
                  Your account is protected by Supabase authentication.
                </Text>
              </View>
              <View style={{ height: spacing.x6 }} />

              {isLoading ? (
                <View className="items-center">
                  <ActivityIndicator color={colors.primary} />
                </View>
              ) : (
                <GradientActionButton
                  label="Create account"
                  onPress={handlePress}
                  icon={<MaterialIcons name="arrow-forward" size={20} color={colors.onPrimary} />}
                />
              )}
            </AuthCard>

            <View style={{ height: spacing.x6 }} />
            <View className="flex-row flex-wrap items-center justify-center">
              <Text className="text-textSm font-outfitRegular text-textMuted">Already have an account? </Text>
              <Pressable accessibilityRole="button" onPress={() => router.replace(AppRoutes.login)}>
                <Text className="text-link font-outfitSemiBold text-primary">Sign in</Text>
              </Pressable>
            </View>
          </View>
        </ScrollView>
      </SafeAreaView>
    </AuthPageBackground>
  );
}
