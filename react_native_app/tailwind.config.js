/**
 * NativeWind / Tailwind token source for the Eatzy (Zivo) React Native app.
 *
 * Ports, token-for-token, flutter_app/lib/config/tailwind.dart (TwColors,
 * TwSpacing, TwRadius, TwText) plus the ad-hoc BoxShadow values used by
 * flutter_app/lib/widgets/app_cards.dart, app_widgets.dart and
 * services/food/presentation/widgets/category_header_delegate.dart (there is
 * no TwShadow class on the Flutter side yet). See issue #352.
 *
 * Every semantic color (the "bg"/"card"/"primary"/... aliases, as opposed to
 * the raw slate/stone/blue/red scale) is wired to a CSS variable so the same
 * class name (e.g. `bg-bg`, `text-text`) automatically resolves to the right
 * value in light or dark mode. The variables themselves are defined for
 * `:root` and for `@media (prefers-color-scheme: dark)` in `src/global.css`.
 *
 * flutter_app has no dark `ThemeData` today, so the dark values below are
 * this port's own choice, not a 1:1 Flutter source — see the comment above
 * the dark block in src/global.css and src/theme/tokens.ts for the reasoning
 * (orchestrator/design should sanity check these before they ship broadly).
 */

function withAlpha(cssVar) {
  return `rgb(var(${cssVar}) / <alpha-value>)`;
}

/** @type {import('tailwindcss').Config} */
module.exports = {
  // Flutter has no dark-mode toggle either; follow the OS setting, matching
  // app.json's `userInterfaceStyle: "automatic"`.
  darkMode: 'media',
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      colors: {
        // --- TwColors: raw palette (identical in light & dark, same as the
        // Flutter scale — these are fixed swatches, not theme-dependent). ---
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

        // --- TwColors: semantic aliases (light/dark via CSS variables). ---
        bg: withAlpha('--color-bg'),
        bgMuted: withAlpha('--color-bg-muted'),
        card: withAlpha('--color-card'),
        cardMuted: withAlpha('--color-card-muted'),
        searchFill: withAlpha('--color-search-fill'),
        border: withAlpha('--color-border'),
        borderStrong: withAlpha('--color-border-strong'),
        text: withAlpha('--color-text'),
        textMuted: withAlpha('--color-text-muted'),
        primary: withAlpha('--color-primary'),
        primaryHover: withAlpha('--color-primary-hover'),
        primarySoft: withAlpha('--color-primary-soft'),
        primaryAccent: withAlpha('--color-primary-accent'),
        onPrimary: withAlpha('--color-on-primary'),
        secondary: withAlpha('--color-secondary'),
        secondarySoft: withAlpha('--color-secondary-soft'),
        tertiary: withAlpha('--color-tertiary'),
        error: withAlpha('--color-error'),
        errorSoft: withAlpha('--color-error-soft'),

        // NOTE: `primaryGradient` (TwColors.primaryGradient, a
        // blue500->blue600 LinearGradient) has no single-color Tailwind
        // representation and is intentionally omitted here. It is exported
        // from src/theme/tokens.ts in the shape expo-linear-gradient expects
        // (`colors`/`start`/`end`) for components that need it.
      },

      // --- TwSpacing. Keys match the Dart field names exactly (including
      // the `x2_5`/`x3_5` half-step names), so nothing is renamed. ---
      spacing: {
        px: '1px',
        x1: '4px',
        x2: '8px',
        x3: '12px',
        x4: '16px',
        x5: '20px',
        x6: '24px',
        x8: '32px',
        x10: '40px',
        x12: '48px',
        x2_5: '10px',
        x3_5: '14px',
        screenX: '20px',
        sectionGap: '32px',
        sectionGapDense: '28px',
        headerToContent: '14px',
        gridGap: '10px',
        carouselGap: '12px',
        listRowY: '14px',
        iconButtonGap: '8px',
        navHeight: '88px',
        navBarContentHeight: '64px',
        bottomScrollInset: '110px',
        bottomScrollInsetWithCta: '190px',
      },

      // --- TwRadius. ---
      borderRadius: {
        sm: '6px',
        base: '8px',
        md: '10px',
        lg: '14px',
        xl: '20px',
        chip: '12px',
        control: '14px',
        input: '16px',
        tile: '16px',
        media: '18px',
        card: '20px',
        hero: '24px',
        full: '9999px',
      },

      // --- Shadows. Not a named class in tailwind.dart today — these mirror
      // the concrete `BoxShadow`s already in use on the Flutter side, kept
      // static across light/dark (Flutter doesn't vary them either). ---
      boxShadow: {
        // ThemeData.cardTheme: shadowColor slate900 @ 12%, elevation 0.6.
        card: '0 1px 3px rgba(15, 23, 42, 0.12)',
        // widgets/app_cards.dart PrimaryButton: scheme.primary @ 18%, blur 12, offset (0, 5).
        button: '0 5px 12px rgba(0, 102, 204, 0.18)',
        // widgets/app_widgets.dart AuthCard: slate900 @ 8%, blur 18, offset (0, 8).
        panel: '0 8px 18px rgba(15, 23, 42, 0.08)',
        // services/food/.../category_header_delegate.dart sticky header: slate900 @ ~8%, blur 12, offset (0, 4).
        header: '0 4px 12px rgba(15, 23, 42, 0.08)',
      },

      // --- Outfit, bundled via app.json's `expo-font` config plugin from
      // react_native_app/assets/fonts/Outfit-*.ttf (issue #353). Ports
      // flutter_app/lib/config/tailwind.dart's `fontFamily: 'Outfit'` +
      // `fontWeight` pairs and pubspec.yaml's weight -> filename mapping
      // (w400 -> Regular, w500 -> Medium, w600 -> SemiBold, w700 -> Bold).
      // Unlike Flutter's single `Outfit` family + `FontWeight` (resolved by
      // the engine against the weight-tagged assets registered in
      // pubspec.yaml), React Native has no automatic weight resolution for a
      // custom font — each weight is its own family name here, so pair the
      // matching `font-outfit*` class with every `text-*` type-scale class
      // below (e.g. `className="text-text3xl font-outfitBold"`). See
      // src/theme/tokens.ts's `fontFamily`/`typography` exports for the same
      // pairing as plain JS values. ---
      fontFamily: {
        outfitRegular: ['Outfit-Regular'],
        outfitMedium: ['Outfit-Medium'],
        outfitSemiBold: ['Outfit-SemiBold'],
        outfitBold: ['Outfit-Bold'],
      },

      // --- TwText. Font sizes carry weight/line-height/letter-spacing like
      // the Dart TextStyles do; color is applied separately via the `text`/
      // `textMuted` color tokens above (Tailwind keeps color and type-scale
      // utilities independent, unlike a Flutter TextStyle). Pair each class
      // below with the `font-outfit*` class matching its `fontWeight` (see
      // the `fontFamily` block above) — Tailwind's `fontSize` tuple format
      // has no `fontFamily` slot of its own. ---
      fontSize: {
        text3xl: ['30px', { lineHeight: '1.15', fontWeight: '700' }],
        text2xl: ['26px', { lineHeight: '1.2', fontWeight: '700' }],
        textXl: ['22px', { lineHeight: '1.25', fontWeight: '700' }],
        textLg: ['19px', { lineHeight: '1.4', fontWeight: '500' }],
        textBase: ['17px', { lineHeight: '1.4', fontWeight: '400' }],
        textSm: ['15px', { lineHeight: '1.35', fontWeight: '400' }],
        textXs: ['13px', { lineHeight: '1.3', fontWeight: '500' }],
        fontBoldSm: ['15px', { lineHeight: '1.35', fontWeight: '600' }],
        fontBoldBase: ['17px', { lineHeight: '1.4', fontWeight: '600' }],
        button: ['15px', { fontWeight: '600' }],
        link: ['13px', { lineHeight: '1.3', fontWeight: '600' }],
        sectionLabel: [
          '13px',
          { lineHeight: '1.3', fontWeight: '700', letterSpacing: '0.6px' },
        ],
        sectionTitle: [
          '20px',
          { lineHeight: '1.25', fontWeight: '600', letterSpacing: '-0.4px' },
        ],
      },
    },
  },
  plugins: [],
};
