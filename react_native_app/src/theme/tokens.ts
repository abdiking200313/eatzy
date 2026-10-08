/**
 * JS-value mirror of tailwind.config.js, for code that needs a real value
 * rather than a className — status bar color, charts, `expo-linear-gradient`
 * props, etc. (issue #352).
 *
 * This is the TypeScript side of the same port: flutter_app/lib/config/
 * tailwind.dart's TwColors/TwSpacing/TwRadius/TwText, token-for-token, plus
 * the Flutter BoxShadow usages listed below. Keep this file and
 * tailwind.config.js in sync — same names, same values.
 */

// --- TwColors: raw palette. Fixed swatches, identical in light & dark. ---
export const rawColors = {
  white: '#FFFFFF',
  transparent: 'transparent',

  slate900: '#0F172A',
  slate700: '#334155',
  slate600: '#475569',
  slate500: '#64748B',

  stone50: '#FAFAF9',
  stone100: '#F5F5F4',
  stone200: '#E7E5E4',
  stone300: '#D6D3D1',
  stone500: '#78716C',
  stone700: '#44403C',
  stone900: '#1C1917',

  blue50: '#F0F7FF',
  blue100: '#E1EEFF',
  blue200: '#C4DCFF',
  blue400: '#66A8FF',
  blue500: '#007FFF',
  blue600: '#0066CC',
  blue700: '#0052A3',
  blue900: '#16345C',

  red100: '#FEE2E2',
  red600: '#DC2626',
  red700: '#B91C1C',
} as const;

// --- TwColors: semantic aliases, light mode. Ports TwColors 1:1. ---
export const semanticColorsLight = {
  bg: '#FAFBFC',
  bgMuted: rawColors.blue50,
  card: rawColors.white,
  cardMuted: '#F8FAFD',
  searchFill: '#EEF1F5',
  border: '#E2E8F0',
  borderStrong: '#CBD5E1',
  text: rawColors.slate900,
  textMuted: rawColors.slate600,
  primary: rawColors.blue600,
  primaryHover: rawColors.blue700,
  primarySoft: rawColors.blue50,
  primaryAccent: rawColors.blue500,
  onPrimary: rawColors.white,
  secondary: rawColors.blue500,
  secondarySoft: rawColors.blue50,
  tertiary: '#10B981',
  error: rawColors.red600,
  errorSoft: rawColors.red100,
} as const;

/**
 * Semantic aliases, dark mode. flutter_app has no dark `ThemeData` yet, so
 * these are this port's own values (issue #352), not a 1:1 Flutter source:
 * neutrals/surfaces are inverted for a dark background, and the
 * primary/secondary/accent brand hues are shifted one step lighter on their
 * own Tailwind-style scale (blue600 -> blue500, blue500 -> blue400) purely
 * for contrast against a dark surface. Must stay in sync with the
 * `@media (prefers-color-scheme: dark)` block in src/global.css. Flag for
 * design review before this palette is treated as final.
 */
export const semanticColorsDark = {
  bg: '#0B1220',
  bgMuted: '#111A2E',
  card: '#16213A',
  cardMuted: '#1C2A47',
  searchFill: '#1C2A47',
  border: '#28334A',
  borderStrong: '#3A4664',
  text: '#F1F5F9',
  textMuted: '#94A3B8',
  primary: rawColors.blue500,
  primaryHover: rawColors.blue400,
  primarySoft: rawColors.blue900,
  primaryAccent: rawColors.blue400,
  onPrimary: rawColors.white,
  secondary: rawColors.blue400,
  secondarySoft: rawColors.blue900,
  tertiary: '#34D399',
  error: '#F87171',
  errorSoft: '#3F1D1D',
} as const;

export const colors = {
  light: { ...rawColors, ...semanticColorsLight },
  dark: { ...rawColors, ...semanticColorsDark },
} as const;

/**
 * TwColors.primaryGradient: a blue500 -> blue600 top-left to bottom-right
 * gradient. Has no single-color Tailwind/NativeWind representation, so it
 * is only exported here, shaped for `expo-linear-gradient`'s
 * `colors`/`start`/`end` props:
 *
 *   <LinearGradient colors={primaryGradient.colors} start={primaryGradient.start} end={primaryGradient.end} />
 */
export const primaryGradient = {
  colors: [rawColors.blue500, rawColors.blue600] as const,
  start: { x: 0, y: 0 },
  end: { x: 1, y: 1 },
} as const;

// --- TwSpacing. Keys match the Dart field names exactly, in logical
// pixels (same unit Flutter's `double` spacing constants use). ---
export const spacing = {
  px: 1,
  x1: 4,
  x2: 8,
  x3: 12,
  x4: 16,
  x5: 20,
  x6: 24,
  x8: 32,
  x10: 40,
  x12: 48,
  x2_5: 10,
  x3_5: 14,
  screenX: 20,
  sectionGap: 32,
  sectionGapDense: 28,
  headerToContent: 14,
  gridGap: 10,
  carouselGap: 12,
  listRowY: 14,
  iconButtonGap: 8,
  navHeight: 88,
  navBarContentHeight: 64,
  bottomScrollInset: 110,
  bottomScrollInsetWithCta: 190,
} as const;

// --- TwRadius. ---
export const radius = {
  sm: 6,
  base: 8,
  md: 10,
  lg: 14,
  xl: 20,
  chip: 12,
  control: 14,
  input: 16,
  tile: 16,
  media: 18,
  card: 20,
  hero: 24,
  full: 9999,
} as const;

/**
 * Shadows. Not a named class in tailwind.dart today — these mirror the
 * concrete Flutter `BoxShadow`s already in use:
 *   - card: ThemeData.cardTheme (shadowColor slate900 @ 12%, elevation 0.6)
 *   - button: widgets/app_cards.dart PrimaryButton (scheme.primary @ 18%, blur 12, offset (0, 5))
 *   - panel: widgets/app_widgets.dart AuthCard (slate900 @ 8%, blur 18, offset (0, 8))
 *   - header: services/food/.../category_header_delegate.dart sticky header (slate900 @ ~8%, blur 12, offset (0, 4))
 * Kept static across light/dark, matching tailwind.config.js's `boxShadow`.
 */
export const shadows = {
  card: {
    shadowColor: rawColors.slate900,
    shadowOpacity: 0.12,
    shadowRadius: 3,
    shadowOffset: { width: 0, height: 1 },
    elevation: 1,
  },
  button: {
    shadowColor: semanticColorsLight.primary,
    shadowOpacity: 0.18,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 5 },
    elevation: 5,
  },
  panel: {
    shadowColor: rawColors.slate900,
    shadowOpacity: 0.08,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
    elevation: 8,
  },
  header: {
    shadowColor: rawColors.slate900,
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 4,
  },
} as const;

/**
 * TwText. Font sizes carry weight/line-height/letter-spacing like the Dart
 * TextStyles do; color is intentionally not baked in here (apply it
 * separately from `colors.light.text` / `colors.light.textMuted`, same as
 * the `text-text`/`text-textMuted` Tailwind classes do). `fontFamily:
 * 'Outfit'` itself is not wired up here — loading/registering the bundled
 * Outfit font is a separate task, not part of #352.
 */
export const typography = {
  text3xl: { fontSize: 30, fontWeight: '700', lineHeight: 1.15 },
  text2xl: { fontSize: 26, fontWeight: '700', lineHeight: 1.2 },
  textXl: { fontSize: 22, fontWeight: '700', lineHeight: 1.25 },
  textLg: { fontSize: 19, fontWeight: '500', lineHeight: 1.4 },
  textBase: { fontSize: 17, fontWeight: '400', lineHeight: 1.4 },
  textSm: { fontSize: 15, fontWeight: '400', lineHeight: 1.35 },
  textXs: { fontSize: 13, fontWeight: '500', lineHeight: 1.3 },
  fontBoldSm: { fontSize: 15, fontWeight: '600', lineHeight: 1.35 },
  fontBoldBase: { fontSize: 17, fontWeight: '600', lineHeight: 1.4 },
  button: { fontSize: 15, fontWeight: '600' },
  link: { fontSize: 13, fontWeight: '600', lineHeight: 1.3 },
  sectionLabel: {
    fontSize: 13,
    fontWeight: '700',
    lineHeight: 1.3,
    letterSpacing: 0.6,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    lineHeight: 1.25,
    letterSpacing: -0.4,
  },
} as const;

export type ColorScheme = keyof typeof colors;
export type SemanticColorToken = keyof typeof semanticColorsLight;
export type RawColorToken = keyof typeof rawColors;
export type SpacingToken = keyof typeof spacing;
export type RadiusToken = keyof typeof radius;
export type ShadowToken = keyof typeof shadows;
export type TypographyToken = keyof typeof typography;
