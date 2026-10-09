import { ActivityIndicator, View } from 'react-native';

import { usePasswordRecoveryRedirect } from '@/platform/navigation/use-password-recovery-redirect';

/**
 * Landing route for the `zivo://reset-callback` deep link Supabase
 * redirects a password-recovery email link to (`PASSWORD_RECOVERY_
 * REDIRECT_URL` in `password-recovery.ts`, mirroring `AuthService.
 * passwordRecoveryRedirectUrl` on the Flutter side -- issue #361).
 *
 * This route exists only so `usePasswordRecoveryRedirect` has somewhere to
 * run its effect: Expo Router's own native deep-link handling resolves
 * `zivo://reset-callback...` to this exact path regardless (see that
 * hook's top comment), so without a matching route here the link would
 * land on `+not-found` instead. Renders nothing but a spinner --
 * `usePasswordRecoveryRedirect` starts the recovery session from the
 * tokens in the URL and replaces this route with `/reset-password` as soon
 * as that resolves.
 */
export default function ResetCallbackScreen() {
  usePasswordRecoveryRedirect();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <ActivityIndicator />
    </View>
  );
}
