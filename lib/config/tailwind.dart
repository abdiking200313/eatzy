import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TwColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Colors.transparent;

  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);

  static const Color stone50 = Color(0xFFFAFAF9);
  static const Color stone100 = Color(0xFFF5F5F4);
  static const Color stone200 = Color(0xFFE7E5E4);
  static const Color stone300 = Color(0xFFD6D3D1);
  static const Color stone500 = Color(0xFF78716C);
  static const Color stone700 = Color(0xFF44403C);
  static const Color stone900 = Color(0xFF1C1917);

  static const Color orange50 = Color(0xFFFFF7ED);
  static const Color orange100 = Color(0xFFFFEDD5);
  static const Color orange200 = Color(0xFFFED7AA);
  static const Color orange500 = Color(0xFFF97316);
  static const Color orange600 = Color(0xFFEA580C);
  static const Color orange700 = Color(0xFFC2410C);
  static const Color orange900 = Color(0xFF7C2D12);

  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber700 = Color(0xFFB45309);

  static const Color violet100 = Color(0xFFEDE9FE);
  static const Color violet400 = Color(0xFFA78BFA);
  static const Color violet600 = Color(0xFF7C3AED);

  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red700 = Color(0xFFB91C1C);

  static const Color bg = stone50;
  static const Color bgMuted = stone100;
  static const Color card = white;
  static const Color cardMuted = stone100;
  static const Color border = stone200;
  static const Color borderStrong = stone300;
  static const Color text = stone900;
  static const Color textMuted = stone500;
  static const Color primary = orange600;
  static const Color primaryHover = orange700;
  static const Color primarySoft = orange100;
  static const Color primaryAccent = orange500;
  static const Color onPrimary = white;
  static const Color secondary = amber700;
  static const Color secondarySoft = amber100;
  static const Color tertiary = violet600;
  static const Color error = red600;
  static const Color errorSoft = red100;

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange500, amber400],
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
}

class TwRadius {
  static const double sm = 2.0;
  static const double base = 4.0;
  static const double md = 6.0;
  static const double lg = 8.0;
  static const double xl = 12.0;
  static const double full = 9999.0;
}

class TwText {
  static TextStyle text3xl() => GoogleFonts.epilogue(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.15,
    color: TwColors.text,
  );

  static TextStyle text2xl() => GoogleFonts.epilogue(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: TwColors.text,
  );

  static TextStyle textXl() => GoogleFonts.epilogue(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: TwColors.text,
  );

  static TextStyle textLg() => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: TwColors.text,
  );

  static TextStyle textBase() => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: TwColors.text,
  );

  static TextStyle textSm() => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: TwColors.textMuted,
  );

  static TextStyle textXs() => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: TwColors.text,
  );

  static TextStyle fontBoldSm() =>
      textSm().copyWith(fontWeight: FontWeight.w700, color: TwColors.text);

  static TextStyle fontBoldBase() =>
      textBase().copyWith(fontWeight: FontWeight.w700);

  static TextStyle button() => GoogleFonts.epilogue(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: TwColors.onPrimary,
  );

  static TextStyle link() =>
      textXs().copyWith(fontWeight: FontWeight.w700, color: TwColors.primary);
}

ThemeData buildAppTheme() {
  final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

  return ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: TwColors.bg,
    primaryColor: TwColors.primary,
    colorScheme: const ColorScheme.light(
      primary: TwColors.primary,
      onPrimary: TwColors.onPrimary,
      secondary: TwColors.secondary,
      onSecondary: TwColors.onPrimary,
      error: TwColors.error,
      onError: TwColors.onPrimary,
      surface: TwColors.bg,
      onSurface: TwColors.text,
    ),
    textTheme: baseTextTheme.copyWith(
      displayLarge: TwText.text3xl(),
      displayMedium: TwText.text3xl(),
      displaySmall: TwText.text2xl(),
      headlineSmall: TwText.text3xl(),
      titleLarge: TwText.textXl(),
      titleMedium: TwText.fontBoldBase(),
      titleSmall: TwText.fontBoldSm(),
      bodyLarge: TwText.textLg(),
      bodyMedium: TwText.textBase(),
      bodySmall: TwText.textSm(),
      labelLarge: TwText.button(),
      labelMedium: TwText.fontBoldSm(),
      labelSmall: TwText.textXs(),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: TwColors.bg,
      elevation: 0,
      foregroundColor: TwColors.text,
      titleTextStyle: TwText.text3xl(),
    ),
  );
}

extension ColorHelpers on Color {
  Color withOpacityValue(double opacity) => withAlpha((opacity * 255).round());
}
