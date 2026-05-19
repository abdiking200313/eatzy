import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color surface = Color(0xFFFCF9F8);
  static const Color surfaceDim = Color(0xFFDCD9D9);
  static const Color surfaceBright = Color(0xFFFCF9F8);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF6F3F2);
  static const Color surfaceContainer = Color(0xFFF0EDEC);
  static const Color surfaceContainerHigh = Color(0xFFEBE7E7);
  static const Color surfaceContainerHighest = Color(0xFFE5E2E1);
  static const Color onSurface = Color(0xFF1C1B1B);
  static const Color onSurfaceVariant = Color(0xFF5B4137);
  static const Color inverseSurface = Color(0xFF313030);
  static const Color inverseOnSurface = Color(0xFFF3F0EF);
  static const Color outline = Color(0xFF8F7065);
  static const Color outlineVariant = Color(0xFFE4BEB1);
  static const Color surfaceTint = Color(0xFFA73A00);
  static const Color primary = Color(0xFFA73A00);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFF5C00);
  static const Color onPrimaryContainer = Color(0xFF521800);
  static const Color inversePrimary = Color(0xFFFFB59A);
  static const Color primaryFixed = Color(0xFFFFDBCE);
  static const Color primaryFixedDim = Color(0xFFFFB59A);
  static const Color onPrimaryFixed = Color(0xFF370E00);
  static const Color onPrimaryFixedVariant = Color(0xFF802A00);
  static const Color secondary = Color(0xFF7A5900);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFDBC00);
  static const Color onSecondaryContainer = Color(0xFF6B4D00);
  static const Color secondaryFixed = Color(0xFFFFDEA2);
  static const Color secondaryFixedDim = Color(0xFFFDBC00);
  static const Color onSecondaryFixed = Color(0xFF261900);
  static const Color onSecondaryFixedVariant = Color(0xFF5C4200);
  static const Color tertiary = Color(0xFF7212FF);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFA27AFF);
  static const Color onTertiaryContainer = Color(0xFF360083);
  static const Color tertiaryFixed = Color(0xFFE9DDFF);
  static const Color tertiaryFixedDim = Color(0xFFD1BCFF);
  static const Color onTertiaryFixed = Color(0xFF23005B);
  static const Color onTertiaryFixedVariant = Color(0xFF5700C9);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color background = Color(0xFFFCF9F8);
  static const Color onBackground = Color(0xFF1C1B1B);
  static const LinearGradient fireSunGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5C00), Color(0xFFFFB59A)],
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double base = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double containerMargin = 20.0;
  static const double gutter = 16.0;
}

class AppRadii {
  static const double sm = 2.0;
  static const double defaultRadius = 4.0;
  static const double md = 6.0;
  static const double lg = 8.0;
  static const double xl = 12.0;
  static const double full = 9999.0;
}

class AppTextStyles {
  static TextStyle h1() => GoogleFonts.epilogue(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.02,
    color: AppColors.onBackground,
  );

  static TextStyle h2() => GoogleFonts.epilogue(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.01,
    color: AppColors.onBackground,
  );

  static TextStyle h3() => GoogleFonts.epilogue(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.onBackground,
  );

  static TextStyle bodyLg() => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.onBackground,
  );

  static TextStyle bodyMd() => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.onBackground,
  );

  static TextStyle labelBold() => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.onBackground,
  );

  static TextStyle labelSm() => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.onBackground,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: AppColors.surface,
    primaryColor: AppColors.primary,
    fontFamily: 'Plus Jakarta Sans',
  );
}

extension ColorHelpers on Color {
  /// Replace deprecated `withOpacity` use with this helper.
  /// Converts an opacity value in 0..1 to an alpha int.
  Color withOpacityValue(double opacity) => withAlpha((opacity * 255).round());
}
