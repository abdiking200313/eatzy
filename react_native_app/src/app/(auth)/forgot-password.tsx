import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppTextField } from '@/components/app-text-field';
import { AuthCard } from '@/components/auth-card';
import { AuthPageBackground } from '@/components/auth-page-background';
import { GradientActionButton } from '@/components/gradient-action-button';
import { ZivoLogo } from '@/components/zivo-logo';
import { describeAuthError } from '@/features/auth/api/auth-error-message';
import { authService } from '@/features/auth/api/auth-service';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { rawColors, spacing } from '@/theme/tokens';

// Ports flutter_app/lib/features/auth/presentation/forgot_password_screen.dart's
// `ForgotPasswordScreen` (issue #368).
//
// Only an empty-field check gates submission here, exactly like the Dart
// screen's `_sendResetLink` -- no email-format validation is added, matching
// `login.tsx`'s own doc comment about deliberately not going beyond the
// Dart original's validation. `AuthService.resetPasswordForEmail` doesn't
// reveal whether the account exists, so the "sent" copy below stays exactly
// as vague as the Dart screen's.
//
// Departure from the Dart source: `_showMessage`'s raw `'Could not send
// reset link: $error'` (the exception's own `toString()`) is replaced here
// with `describeAuthError`, the same safe, fixed-copy error mapping
// `login.tsx`/`register.tsx` already use for every other auth error in this
// app -- showing a raw Supabase error string would leak internal detail
// `describeAuthError`'s own doc comment says a screenshot-able UI message
// never should.
export default function ForgotPasswordScreen() {
  const colors = useSemanticColors();
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [linkSent, setLinkSent] = useState(false);

  const handleSendResetLink = async () => {
    const trimmedEmail = email.trim();
    if (trimmedEmail.length === 0) {
      setMessage('Enter your email address.');
      return;
    }

    setMessage(null);
    setIsLoading(true);
    try {
      await authService.resetPasswordForEmail(trimmedEmail);
      setLinkSent(true);
    } catch (error) {
      setMessage(`Could not send reset link: ${describeAuthError(error, 'ForgotPassword')}`);
    } finally {
      setIsLoading(false);
    }
  };

  // Mirrors the Dart screen's back button: always rendered, but only acts
  // when there is something to pop back to -- it does not fall back to
  // another route like `login.tsx`'s own `handleBack` does, because the
  // Dart original (`if (context.canPop()) context.pop();`) has no such
  // fallback either.
  const handleBack = () => {
    if (router.canGoBack()) {
      router.back();
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
              {linkSent ? (
                <>
                  <MaterialIcons name="mark-email-read" size={40} color={colors.primary} />
                  <View style={{ height: spacing.x4 }} />
                  <Text className="text-text3xl font-outfitBold text-text">Check your email</Text>
                  <View style={{ height: spacing.x2 }} />
                  <Text className="text-textSm font-outfitRegular text-textMuted">
                    If an account exists for {email.trim()}, we&apos;ve sent a link to reset your password. Open it
                    on this device to continue.
                  </Text>
                  <View style={{ height: spacing.x6 }} />
                  <GradientActionButton
                    label="Back to sign in"
                    onPress={() => router.replace(AppRoutes.login)}
                    icon={<MaterialIcons name="arrow-forward" size={20} color={colors.onPrimary} />}
                  />
                </>
              ) : (
                <>
                  <Text className="text-text3xl font-outfitBold text-text">Forgot password?</Text>
                  <View style={{ height: spacing.x2 }} />
                  <Text className="text-textSm font-outfitRegular text-textMuted">
                    Enter the email on your account and we&apos;ll send you a link to reset your password.
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
                    label="Email address"
                    hint="you@example.com"
                    value={email}
                    onChangeText={setEmail}
                    keyboardType="email-address"
                    prefixIcon="mail-outline"
                    textInputAction="done"
                    autoComplete="email"
                    onSubmitted={() => {
                      if (!isLoading) handleSendResetLink();
                    }}
                  />
                  <View style={{ height: spacing.x6 }} />

                  {isLoading ? (
                    <View className="items-center">
                      <ActivityIndicator color={colors.primary} />
                    </View>
                  ) : (
                    <GradientActionButton
                      label="Send reset link"
                      onPress={handleSendResetLink}
                      icon={<MaterialIcons name="arrow-forward" size={20} color={colors.onPrimary} />}
                    />
                  )}
                </>
              )}
            </AuthCard>

            <View style={{ height: spacing.x6 }} />
            <View className="flex-row flex-wrap items-center justify-center">
              <Text className="text-textSm font-outfitRegular text-textMuted">Remembered it? </Text>
              <Pressable accessibilityRole="button" onPress={() => router.replace(AppRoutes.login)}>
                <Text className="text-link font-outfitSemiBold text-primary">Back to sign in</Text>
              </Pressable>
            </View>
          </View>
        </ScrollView>
      </SafeAreaView>
    </AuthPageBackground>
  );
}
