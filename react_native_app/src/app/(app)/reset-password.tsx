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

// Ports flutter_app/lib/features/auth/presentation/reset_password_screen.dart's
// `ResetPasswordScreen` (issue #368).
//
// Reachable both from Settings (an already-authenticated session) and
// after tapping a password-recovery email link (a temporary recovery
// session) -- both cases already have a valid Supabase session by the time
// this screen is shown, so no current-password field is required; see
// `AuthService.updatePassword`.
//
// Departure from the Dart source: `_showMessage`'s raw
// `'Could not update password: $error'` is replaced here with
// `describeAuthError`, the same safe, fixed-copy error mapping
// `login.tsx`/`register.tsx`/`forgot-password.tsx` already use for every
// other auth error in this app, instead of a raw Supabase error string.
export default function ResetPasswordScreen() {
  const colors = useSemanticColors();
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [message, setMessage] = useState<{ text: string; tone: 'error' | 'success' } | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleUpdatePassword = async () => {
    if (password.length === 0 || confirmPassword.length === 0) {
      setMessage({ text: 'Please fill in both fields.', tone: 'error' });
      return;
    }
    if (password.length < 6) {
      setMessage({ text: 'Password must be at least 6 characters.', tone: 'error' });
      return;
    }
    if (password !== confirmPassword) {
      setMessage({ text: 'Passwords do not match.', tone: 'error' });
      return;
    }

    setMessage(null);
    setIsLoading(true);
    try {
      await authService.updatePassword(password);
      setMessage({ text: 'Password updated.', tone: 'success' });
      if (router.canGoBack()) {
        router.back();
      } else {
        router.replace(AppRoutes.mainApp);
      }
    } catch (error) {
      setMessage({
        text: `Could not update password: ${describeAuthError(error, 'ResetPassword')}`,
        tone: 'error',
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <AuthPageBackground>
      <SafeAreaView edges={['top', 'bottom']} className="flex-1">
        <ScrollView contentContainerStyle={{ padding: spacing.x5 }} keyboardShouldPersistTaps="handled">
          <View className="w-full items-center self-center" style={{ maxWidth: 460 }}>
            {/* Mirrors the Dart screen's `if (context.canPop()) Align(...)`:
                unlike `forgot-password.tsx`'s always-rendered back button,
                this one is only rendered at all when there is a screen to
                pop back to -- there isn't one when this screen is reached
                straight off a password-recovery email deep link. */}
            {router.canGoBack() && (
              <View className="w-full flex-row">
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel="Back"
                  onPress={() => router.back()}
                  style={{ backgroundColor: rawColors.white, width: 44, height: 44, borderRadius: 22 }}
                  className="items-center justify-center active:opacity-70">
                  <MaterialIcons name="arrow-back" size={22} color={colors.text} />
                </Pressable>
              </View>
            )}
            <View style={{ height: spacing.x6 }} />
            <ZivoLogo height={48} />
            <View style={{ height: spacing.x8 }} />

            <AuthCard>
              <Text className="text-text3xl font-outfitBold text-text">Set a new password</Text>
              <View style={{ height: spacing.x2 }} />
              <Text className="text-textSm font-outfitRegular text-textMuted">
                Choose a new password for your account.
              </Text>
              <View style={{ height: spacing.sectionGap }} />

              {message && (
                <>
                  <Text
                    accessibilityRole="alert"
                    className={
                      message.tone === 'error'
                        ? 'text-textSm font-outfitMedium text-error'
                        : 'text-textSm font-outfitMedium text-text'
                    }>
                    {message.text}
                  </Text>
                  <View style={{ height: spacing.x3 }} />
                </>
              )}

              <AppTextField
                label="New password"
                hint="At least 6 characters"
                value={password}
                onChangeText={setPassword}
                prefixIcon="lock-outline"
                obscureText
                textInputAction="next"
                autoComplete="password-new"
              />
              <View style={{ height: spacing.x3_5 }} />
              <AppTextField
                label="Confirm new password"
                hint="Enter the password again"
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                prefixIcon="verified-user"
                obscureText
                textInputAction="done"
                autoComplete="password-new"
                onSubmitted={() => {
                  if (!isLoading) handleUpdatePassword();
                }}
              />
              <View style={{ height: spacing.x6 }} />

              {isLoading ? (
                <View className="items-center">
                  <ActivityIndicator color={colors.primary} />
                </View>
              ) : (
                <GradientActionButton
                  label="Update password"
                  onPress={handleUpdatePassword}
                  icon={<MaterialIcons name="check" size={20} color={colors.onPrimary} />}
                />
              )}
            </AuthCard>
          </View>
        </ScrollView>
      </SafeAreaView>
    </AuthPageBackground>
  );
}
