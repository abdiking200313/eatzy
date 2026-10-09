import { useCallback, useEffect, useRef, useState } from 'react';

// Matches `showCartSnackBar`'s `Duration(milliseconds: 1800)` in
// flutter_app/lib/widgets/app_misc.dart.
const DURATION_MS = 1800;

export type CartSnackbarController = {
  message: string | null;
  /** Shows `message`, replacing (not queuing behind) one already showing —
   * ports `ScaffoldMessenger.clearSnackBars()` running before
   * `showSnackBar` in the Flutter source, so rapid taps don't back up a
   * queue of stale confirmations. */
  show: (message: string) => void;
};

/**
 * Local-state half of flutter_app/lib/widgets/app_misc.dart's
 * `showCartSnackBar`: cart/quantity-update confirmations (e.g. "added to
 * cart", "quantity increased", "maximum reached").
 *
 * The Flutter function is a one-liner callable from anywhere because
 * `ScaffoldMessenger` is an app-wide ambient host; there is no such global
 * host in this app yet. This hook owns the message/timer state for one
 * screen — pair it with `<CartSnackbar message={message} />` in that
 * screen's own (relatively positioned) tree. A cross-screen "show from
 * anywhere" host, if one becomes necessary, would need a provider mounted
 * in a root `_layout.tsx`, which is layout/shell wiring outside this
 * hook's and this issue's scope.
 */
export function useCartSnackbar(): CartSnackbarController {
  const [message, setMessage] = useState<string | null>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const show = useCallback((next: string) => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
    setMessage(next);
    timeoutRef.current = setTimeout(() => setMessage(null), DURATION_MS);
  }, []);

  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  return { message, show };
}
