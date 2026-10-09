import { useColorScheme } from 'react-native';

import { colors, type ColorScheme } from '@/theme/tokens';

/**
 * Resolves theme/tokens.ts's semantic color map for the active color
 * scheme. NativeWind's `bg-*`/`text-*` classes already do this
 * automatically (via the CSS variables wired in tailwind.config.js) for
 * anything styled with a className — this hook exists only for the few
 * cases that need a literal color value instead, e.g. an
 * `@expo/vector-icons` icon's `color` prop (NativeWind has no built-in
 * className interop for third-party icon components).
 */
export function useSemanticColors() {
  const scheme = useColorScheme();
  const resolved: ColorScheme = scheme === 'dark' ? 'dark' : 'light';
  return colors[resolved];
}
