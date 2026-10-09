import { MaterialIcons } from '@expo/vector-icons';
import DateTimePicker, { DateTimePickerAndroid } from '@react-native-community/datetimepicker';
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { ActivityIndicator, Alert, Platform, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppTextField } from '@/components/app-text-field';
import { AuthCard } from '@/components/auth-card';
import { AuthPageBackground } from '@/components/auth-page-background';
import { GradientActionButton } from '@/components/gradient-action-button';
import { ZivoLogo } from '@/components/zivo-logo';
import { describeAuthError } from '@/features/auth/api/auth-error-message';
import { authService } from '@/features/auth/api/auth-service';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { ErrorReporting } from '@/platform/error-reporting/error-reporter';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { rawColors, spacing } from '@/theme/tokens';

// Ports flutter_app/lib/features/auth/presentation/register_screen.dart's
// `RegisterScreen` (issue #366).
//
// Unlike `login.tsx` (issue #365), this screen does *not* collapse
// validation into a single react-hook-form + zod schema: the Dart
// `_register()` method raises a distinct message per distinct failure
// case, in a fixed order, and `register_screen_test.dart` asserts each one
// individually. Plain `useState` per field (mirroring the Dart
// `TextEditingController`s) plus a sequential imperative check replicates
// that 1:1; see each `setMessage` call below for the matching Dart branch.
const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+\-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+$/;
const PHONE_REGEX = /^\+?[0-9\s-]{7,15}$/;

// There's no existing shared formatter for this exact `MMM d, yyyy` shape
// (src/platform/date-format.ts's formatter is a different, longer
// order-timestamp format and belongs to rn-logic-agent) -- formatted
// inline here, matching Dart's `DateFormat('MMM d, yyyy').format(picked)`.
const dobDisplayFormatter = new Intl.DateTimeFormat('en-US', {
  month: 'short',
  day: 'numeric',
  year: 'numeric',
});

export default function RegisterScreen() {
  const colors = useSemanticColors();
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [phone, setPhone] = useState('');
  const [dob, setDob] = useState<Date | null>(null);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isDobPickerVisible, setIsDobPickerVisible] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  // Mirrors `_pickDob`'s bounds: default/initial date is 18 years before
  // today, earliest selectable is 120 years before today, latest is today.
  const dobBounds = useMemo(() => {
    const now = new Date();
    return {
      initial: new Date(now.getFullYear() - 18, now.getMonth(), now.getDate()),
      minimumDate: new Date(now.getFullYear() - 120, now.getMonth(), now.getDate()),
      maximumDate: now,
    };
  }, []);

  const handleDobPress = () => {
    const value = dob ?? dobBounds.initial;
    if (Platform.OS === 'android') {
      // Recommended Android usage for this library is the imperative api
      // (the picker opens as a dialog, similar to `Alert.alert`) rather
      // than the component form used below for iOS.
      DateTimePickerAndroid.open({
        value,
        mode: 'date',
        minimumDate: dobBounds.minimumDate,
        maximumDate: dobBounds.maximumDate,
        onValueChange: (_event, selectedDate) => setDob(selectedDate),
      });
    } else {
      setIsDobPickerVisible(true);
    }
  };

  // Mirrors `_register()`: validates in this exact sequence, each with its
  // own distinct message, then submits the trimmed fields (password/
  // confirmPassword are never trimmed, matching the Dart method).
  const register = async () => {
    setMessage(null);
    const trimmedFirstName = firstName.trim();
    const trimmedLastName = lastName.trim();
    const trimmedPhone = phone.trim();
    const trimmedEmail = email.trim();

    if (
      trimmedFirstName === '' ||
      trimmedLastName === '' ||
      trimmedPhone === '' ||
      dob == null ||
      trimmedEmail === '' ||
      password === '' ||
      confirmPassword === ''
    ) {
      setMessage('Please fill in every field.');
      return;
    }
    if (password.length < 6) {
      setMessage('Password must be at least 6 characters.');
      return;
    }
    if (!EMAIL_REGEX.test(trimmedEmail)) {
      setMessage('Please enter a valid email address.');
      return;
    }
    if (!PHONE_REGEX.test(trimmedPhone)) {
      setMessage('Please enter a valid phone number.');
      return;
    }
    if (password !== confirmPassword) {
      setMessage('Passwords do not match.');
      return;
    }

    setIsLoading(true);
    // Declared with a definite-assignment assertion like Dart's
    // uninitialized `AuthResponse response;` -- it's always assigned
    // before use below, since the only path that skips the assignment
    // (the call throwing) returns from the catch block instead.
    let response!: { session: unknown };
    try {
      // TODO(rn-logic-agent): `signUpWithEmailPassword` lands on
      // `authService` alongside this screen (issue #366's companion
      // logic change) -- this call is written against that contract
      // ahead of the merge.
      response = await authService.signUpWithEmailPassword(trimmedEmail, password, {
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        phone: trimmedPhone,
        dob,
      });
    } catch (error) {
      setMessage(`Registration failed: ${describeAuthError(error, 'Register')}`);
      return;
    } finally {
      setIsLoading(false);
    }

    // Sits outside the try/catch above, same as Dart's post-signup
    // `context.go` calls -- a failure here is never reported as a
    // registration failure.
    if (response.session != null) {
      router.replace(AppRoutes.mainApp);
      return;
    }

    Alert.alert(
      'Confirm your email',
      `We sent a confirmation link to ${trimmedEmail}. Open the link to activate your account, then sign in.`,
      [{ text: 'Go to sign in', onPress: () => router.replace(AppRoutes.login) }],
    );
  };

  // Fire-and-forget, mirroring the Dart screen's un-awaited
  // `onPressed: _register` -- `register()`'s own try/catch already turns a
  // sign-up failure into the inline "Registration failed" message and
  // returns normally, so a rejection here can only come from the
  // post-success navigation code above. Reported rather than silently
  // swallowed, matching `login.tsx`'s `handlePress`.
  const handlePress = () => {
    register().catch((error: unknown) => {
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

              <AppTextField
                label="First name"
                hint="Jane"
                value={firstName}
                onChangeText={setFirstName}
                prefixIcon="person-outline"
                textInputAction="next"
                autoComplete="given-name"
              />
              <View style={{ height: spacing.x3_5 }} />
              <AppTextField
                label="Last name"
                hint="Doe"
                value={lastName}
                onChangeText={setLastName}
                prefixIcon="person-outline"
                textInputAction="next"
                autoComplete="family-name"
              />
              <View style={{ height: spacing.x3_5 }} />
              <AppTextField
                label="Phone number"
                hint="+1 555 123 4567"
                value={phone}
                onChangeText={setPhone}
                keyboardType="phone-pad"
                prefixIcon="phone"
                textInputAction="next"
                autoComplete="tel"
              />
              <View style={{ height: spacing.x3_5 }} />
              <AppTextField
                label="Date of birth"
                hint="Select your date of birth"
                value={dob ? dobDisplayFormatter.format(dob) : ''}
                prefixIcon="cake"
                readOnly
                onPress={handleDobPress}
              />
              {isDobPickerVisible && (
                <>
                  <View style={{ height: spacing.x2 }} />
                  <DateTimePicker
                    value={dob ?? dobBounds.initial}
                    mode="date"
                    display="spinner"
                    minimumDate={dobBounds.minimumDate}
                    maximumDate={dobBounds.maximumDate}
                    onValueChange={(_event, selectedDate) => setDob(selectedDate)}
                    onDismiss={() => setIsDobPickerVisible(false)}
                  />
                  <View className="flex-row justify-end">
                    <Pressable accessibilityRole="button" onPress={() => setIsDobPickerVisible(false)}>
                      <Text className="text-link font-outfitSemiBold text-primary">Done</Text>
                    </Pressable>
                  </View>
                </>
              )}
              <View style={{ height: spacing.x3_5 }} />
              <AppTextField
                label="Email address"
                hint="you@example.com"
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                prefixIcon="mail-outline"
                textInputAction="next"
                autoComplete="email"
              />
              <View style={{ height: spacing.x3_5 }} />
              <AppTextField
                label="Password"
                hint="At least 6 characters"
                value={password}
                onChangeText={setPassword}
                prefixIcon="lock-outline"
                obscureText
                textInputAction="next"
                autoComplete="new-password"
              />
              <View style={{ height: spacing.x3_5 }} />
              <AppTextField
                label="Confirm password"
                hint="Enter the password again"
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                prefixIcon="verified-user"
                obscureText
                textInputAction="done"
                onSubmitted={() => {
                  if (!isLoading) handlePress();
                }}
              />
              <View style={{ height: spacing.x3_5 }} />
              <View className="flex-row items-center">
                <MaterialIcons name="shield" size={16} color={colors.primary} />
                <View style={{ width: spacing.x2 }} />
                <Text className="flex-1 text-textXs font-outfitMedium text-textMuted">
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

            <View style={{ height: spacing.x5 }} />
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
