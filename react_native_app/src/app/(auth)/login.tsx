import { zodResolver } from '@hookform/resolvers/zod';
import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { ActivityIndicator, Pressable, ScrollView, Text, View } from 'react-native';
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
import { AppRoutes } from '@/platform/navigation/app-routes';
import { merchantSessionGate } from '@/stores/merchant-session-gate';
import { rawColors, spacing } from '@/theme/tokens';

// Ports flutter_app/lib/features/auth/presentation/login_screen.dart's
// `LoginScreen` (issue #365).
//
// Only an empty-field check gates submission here, exactly like the Dart
// screen's `_login` -- no email-format/other client-side validation is
// added beyond that, even though `react-hook-form` + `zod` (this issue's
// own chosen form stack) could easily add it. `zod`'s per-field error
// messages are deliberately not surfaced either: an invalid submission
// shows the single combined `'Enter your email and password.'` message
// Dart's `_showMessage` does, via `onInvalid` below, not per-field text.
const loginFormSchema = z.object({
  email: z.string().min(1),
  password: z.string().min(1),
});

type LoginFormValues = z.infer<typeof loginFormSchema>;

export default function LoginScreen() {
  const colors = useSemanticColors();
  const [message, setMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const { control, handleSubmit } = useForm<LoginFormValues>({
    resolver: zodResolver(loginFormSchema),
    defaultValues: { email: '', password: '' },
  });

  // Mirrors `_LoginScreenState._login`: the `MerchantSessionGate.resolveFor`
  // + routing decision sits outside the try/catch around the sign-in call
  // itself, so a failure in *that* part (e.g. `router.replace` throwing)
  // is never reported as a sign-in failure -- see the Dart file's own
  // issue #295 comment.
  const onValid = async ({ email, password }: LoginFormValues) => {
    setMessage(null);
    setIsLoading(true);
    let userId: string | null = null;
    try {
      await authService.signInWithEmailPassword(email.trim(), password);
      userId = authService.getCurrentUserId();
    } catch (error) {
      setMessage(`Login failed: ${describeAuthError(error, 'Login')}`);
      return;
    } finally {
      setIsLoading(false);
    }

    // Same sign-in form for every account -- a `merchant`/`admin`
    // `profiles.role` lands on the merchant dashboard instead of the
    // customer home, decided here right after a successful sign-in (and
    // again on session-restore at app start, and reactively by
    // `(auth)/_layout.tsx`/`(app)/_layout.tsx` themselves -- this call
    // joins whichever lookup is already running rather than starting a
    // second one; see `merchant-session-gate.ts`'s `resolveFor`). A lookup
    // failure fails closed into the customer experience rather than
    // blocking the login.
    if (userId != null) {
      await merchantSessionGate.resolveFor(userId);
    }
    const isMerchant = merchantSessionGate.store.getState().isMerchantRole;
    router.replace(isMerchant ? AppRoutes.merchantDashboard : AppRoutes.mainApp);
  };

  const onInvalid = () => {
    setMessage('Enter your email and password.');
  };

  const submit = handleSubmit(onValid, onInvalid);

  // `submit()` is invoked fire-and-forget below (mirroring the Dart
  // screen's own un-awaited `onPressed: _login`) -- a rejection from it can
  // only come from the post-sign-in resolve+navigate code (`onValid`'s own
  // try/catch already turns a sign-in failure into the "Login failed"
  // message and returns normally; see this file's top comment and the
  // Dart file's issue #295 comment for why that code sits outside the
  // try/catch). Reporting rather than silently swallowing it here matches
  // every other call site's `ErrorReporting` convention in this codebase
  // (e.g. `onboarding-store.ts`) and keeps a genuinely unhandled promise
  // rejection from ever reaching the runtime.
  const handlePress = () => {
    submit().catch((error: unknown) => {
      ErrorReporting.instance.reportError(
        error,
        error instanceof Error ? error.stack : undefined,
        'LoginScreen.handlePress',
      );
    });
  };

  const handleBack = () => {
    // With nothing behind this screen (the app opened straight on login,
    // or it replaced another route) reopen the onboarding slides instead
    // of doing nothing.
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
            <View style={{ height: spacing.x6 }} />
            <ZivoLogo height={48} />
            <View style={{ height: spacing.x8 }} />

            <AuthCard>
              <Text className="text-text3xl font-outfitBold text-text">Welcome back</Text>
              <View style={{ height: spacing.x2 }} />
              <Text className="text-textSm font-outfitRegular text-textMuted">Sign in to continue your orders.</Text>
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
                    hint="Enter your password"
                    value={value}
                    onChangeText={onChange}
                    prefixIcon="lock-outline"
                    obscureText
                    textInputAction="done"
                    autoComplete="password"
                    onSubmitted={() => {
                      if (!isLoading) handlePress();
                    }}
                  />
                )}
              />
              <View style={{ height: spacing.x2 }} />
              <View className="flex-row justify-end">
                <Pressable accessibilityRole="button" onPress={() => router.push(AppRoutes.forgotPassword)}>
                  <Text className="text-link font-outfitSemiBold text-primary">Forgot password?</Text>
                </Pressable>
              </View>
              <View style={{ height: spacing.x6 }} />

              {isLoading ? (
                <View className="items-center">
                  <ActivityIndicator color={colors.primary} />
                </View>
              ) : (
                <GradientActionButton
                  label="Sign in"
                  onPress={handlePress}
                  icon={<MaterialIcons name="arrow-forward" size={20} color={colors.onPrimary} />}
                />
              )}
            </AuthCard>

            <View style={{ height: spacing.x6 }} />
            <View className="flex-row flex-wrap items-center justify-center">
              <Text className="text-textSm font-outfitRegular text-textMuted">New to Zivo? </Text>
              <Pressable accessibilityRole="button" onPress={() => router.replace(AppRoutes.register)}>
                <Text className="text-link font-outfitSemiBold text-primary">Create account</Text>
              </Pressable>
            </View>
          </View>
        </ScrollView>
      </SafeAreaView>
    </AuthPageBackground>
  );
}
