/**
 * The "Replace your cart?" prompt from
 * `TrackOrderScreen._orderAgainPressed`'s `AlertDialog`, as a native
 * `Alert` -- the `confirmReplace` to hand `runOrderAgain` (issue #397).
 */
import { Alert } from 'react-native';

import { ORDER_AGAIN_MESSAGES } from './order-again-service';

/** Resolves `true` when the user taps "Replace", `false` on "Cancel" or dismissal. */
export function confirmReplaceCart(): Promise<boolean> {
  return new Promise((resolve) => {
    Alert.alert(
      ORDER_AGAIN_MESSAGES.replaceTitle,
      ORDER_AGAIN_MESSAGES.replaceBody,
      [
        { text: 'Cancel', style: 'cancel', onPress: () => resolve(false) },
        { text: 'Replace', onPress: () => resolve(true) },
      ],
      { cancelable: true, onDismiss: () => resolve(false) },
    );
  });
}
