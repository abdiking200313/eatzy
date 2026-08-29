import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TwColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Colors.transparent;

  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);

  static const Color stone50 = Color(0xFFFAFAF9);
  static const Color stone100 = Color(0xFFF5F5F4);
  static const Color stone200 = Color(0xFFE7E5E4);
  static const Color stone300 = Color(0xFFD6D3D1);
  static const Color stone500 = Color(0xFF78716C);
  static const Color stone700 = Color(0xFF44403C);
  static const Color stone900 = Color(0xFF1C1917);

  static const Color blue50 = Color(0xFFF0F7FF);
  static const Color blue100 = Color(0xFFE1EEFF);
  static const Color blue200 = Color(0xFFC4DCFF);
  static const Color blue400 = Color(0xFF66A8FF);
  static const Color blue500 = Color(0xFF007FFF);
  static const Color blue600 = Color(0xFF0066CC);
  static const Color blue700 = Color(0xFF0052A3);
  static const Color blue900 = Color(0xFF16345C);

  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red700 = Color(0xFFB91C1C);

  static const Color bg = Color(0xFFFAFBFC);
  static const Color bgMuted = blue50;
  static const Color card = white;
  static const Color cardMuted = Color(0xFFF8FAFD);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color text = Color(0xFF0F172A);
  static const Color textMuted = slate600;
  static const Color primary = blue600;
  static const Color primaryHover = blue700;
  static const Color primarySoft = blue50;
  static const Color primaryAccent = blue500;
  static const Color onPrimary = white;
  static const Color secondary = blue500;
  static const Color secondarySoft = blue50;
  static const Color tertiary = Color(0xFF10B981);
  static const Color error = red600;
  static const Color errorSoft = red100;

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue500, blue600],
  );
}

class TwSpacing {
  static const double px = 1.0;
  static const double x1 = 4.0;
  static const double x2 = 8.0;
  static const double x3 = 12.0;
  static const double x4 = 16.0;
  static const double x5 = 20.0;
  static const double x6 = 24.0;
  static const double x8 = 32.0;
  static const double x10 = 40.0;
  static const double x12 = 48.0;

  /// Redesign component-internal spacing rhythm (tight / default /
  /// section-gap). This is a distinct scale from the `x*` page-layout scale
  /// above — it does not divide evenly into the 4px `x*` grid, so it is kept
  /// as its own named set rather than folded into it. Use these for spacing
  /// *within* a component (e.g. between an icon chip and its label, or
  /// between stacked rows in a card); keep using `x5` (20px) for screen body
  /// padding and the `x*` scale for page-level layout gaps.
  static const double rhythmTight = 6.0;
  static const double rhythmDefault = 14.0;
  static const double rhythmSection = 28.0;
}

class TwRadius {
  static const double sm = 6.0;
  static const double base = 8.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 20.0;
  static const double full = 9999.0;
}

class TwText {
  // Resolved once at first use (not per-build): `GoogleFonts.outfit(...)`
  // does font-asset lookup + TextStyle allocation, so it must not be called
  // by `build()` on every rebuild. See issue #65. `copyWith`-based variants
  // below reuse the already-resolved base style instead of re-resolving.
  static final TextStyle text3xl = GoogleFonts.outfit(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: TwColors.text,
  );

  static final TextStyle text2xl = GoogleFonts.outfit(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: TwColors.text,
  );

  static final TextStyle textXl = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: TwColors.text,
  );

  static final TextStyle textLg = GoogleFonts.outfit(
    fontSize: 19,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: TwColors.text,
  );

  static final TextStyle textBase = GoogleFonts.outfit(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: TwColors.text,
  );

  static final TextStyle textSm = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: TwColors.textMuted,
  );

  static final TextStyle textXs = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: TwColors.text,
  );

  static final TextStyle fontBoldSm = textSm.copyWith(
    fontWeight: FontWeight.w600,
    color: TwColors.text,
  );

  static final TextStyle fontBoldBase = textBase.copyWith(
    fontWeight: FontWeight.w600,
  );

  static final TextStyle button = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: TwColors.onPrimary,
  );

  static final TextStyle link = textXs.copyWith(
    fontWeight: FontWeight.w600,
    color: TwColors.primary,
  );

  /// Small uppercase "eyebrow"/section-kicker style for headings like
  /// "OUR SERVICES". Applied to existing all-caps section headers by
  /// whichever later redesign phase touches that screen.
  static final TextStyle sectionLabel = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.6,
    color: TwColors.textMuted,
  );
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
    primary: TwColors.primary,
    onPrimary: TwColors.onPrimary,
    primaryContainer: TwColors.primarySoft,
    onPrimaryContainer: TwColors.text,
    secondary: TwColors.secondary,
    onSecondary: TwColors.onPrimary,
    secondaryContainer: TwColors.secondarySoft,
    onSecondaryContainer: TwColors.text,
    tertiary: TwColors.tertiary,
    onTertiary: TwColors.slate900,
    error: TwColors.error,
    onError: TwColors.onPrimary,
    errorContainer: TwColors.errorSoft,
    onErrorContainer: TwColors.red700,
    surface: TwColors.bg,
    onSurface: TwColors.text,
    surfaceContainerLowest: TwColors.bg,
    surfaceContainerLow: TwColors.card,
    surfaceContainer: TwColors.card,
    surfaceContainerHigh: TwColors.cardMuted,
    surfaceContainerHighest: TwColors.blue50,
    outline: TwColors.borderStrong,
    outlineVariant: TwColors.border,
  );
  final baseTextTheme = GoogleFonts.outfitTextTheme();
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(TwRadius.xl),
    borderSide: const BorderSide(color: TwColors.border),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: TwColors.bg,
    primaryColor: TwColors.primary,
    colorScheme: colorScheme,
    textTheme: baseTextTheme.copyWith(
      displayLarge: TwText.text3xl,
      displayMedium: TwText.text3xl,
      displaySmall: TwText.text2xl,
      headlineSmall: TwText.text3xl,
      titleLarge: TwText.textXl,
      titleMedium: TwText.fontBoldBase,
      titleSmall: TwText.fontBoldSm,
      bodyLarge: TwText.textLg,
      bodyMedium: TwText.textBase,
      bodySmall: TwText.textSm,
      labelLarge: TwText.button,
      labelMedium: TwText.fontBoldSm,
      labelSmall: TwText.textXs,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: TwColors.bg,
      foregroundColor: TwColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: TwSpacing.x5,
      titleTextStyle: TwText.textXl,
    ),
    cardTheme: CardThemeData(
      color: TwColors.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: TwColors.slate900.withOpacityValue(0.12),
      elevation: 0.6,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TwRadius.xl),
        side: const BorderSide(color: TwColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TwColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x4,
        vertical: TwSpacing.x4,
      ),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TwRadius.xl),
        borderSide: const BorderSide(color: TwColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TwRadius.xl),
        borderSide: const BorderSide(color: TwColors.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TwColors.primary,
        foregroundColor: TwColors.onPrimary,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwRadius.lg),
        ),
        textStyle: TwText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TwColors.primary,
        minimumSize: const Size(44, 44),
        side: const BorderSide(color: TwColors.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TwRadius.lg),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: TwColors.text,
        minimumSize: const Size(44, 44),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: TwColors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TwText.textXs.copyWith(
          color: states.contains(WidgetState.selected)
              ? TwColors.primary
              : TwColors.textMuted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: TwColors.border,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: TwColors.textMuted,
      textColor: TwColors.text,
      contentPadding: EdgeInsets.symmetric(horizontal: TwSpacing.x4),
    ),
  );
}

extension ColorHelpers on Color {
  Color withOpacityValue(double opacity) => withAlpha((opacity * 255).round());
}
