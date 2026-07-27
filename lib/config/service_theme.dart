import 'package:flutter/material.dart';

import '../app/service_module.dart';
import 'tailwind.dart';

@immutable
class ZivoServiceColors extends ThemeExtension<ZivoServiceColors> {
  const ZivoServiceColors({
    required this.accent,
    required this.onAccent,
    required this.soft,
    required this.background,
    required this.card,
    required this.border,
  });

  final Color accent;
  final Color onAccent;
  final Color soft;
  final Color background;
  final Color card;
  final Color border;

  static const platform = ZivoServiceColors(
    accent: TwColors.primary,
    onAccent: TwColors.onPrimary,
    soft: TwColors.primarySoft,
    background: TwColors.bg,
    card: TwColors.card,
    border: TwColors.border,
  );

  @override
  ZivoServiceColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? soft,
    Color? background,
    Color? card,
    Color? border,
  }) {
    return ZivoServiceColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      soft: soft ?? this.soft,
      background: background ?? this.background,
      card: card ?? this.card,
      border: border ?? this.border,
    );
  }

  @override
  ZivoServiceColors lerp(covariant ZivoServiceColors? other, double t) {
    if (other is! ZivoServiceColors) {
      return this;
    }
    return ZivoServiceColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

abstract final class ServiceThemes {
  static const food = ZivoServiceColors(
    accent: Color(0xFFC2410C),
    onAccent: Colors.white,
    soft: Color(0xFFFFE8DC),
    background: Color(0xFFFFF9F5),
    card: Color(0xFFFFF1E9),
    border: Color(0xFFF6C8B1),
  );

  static const grocery = ZivoServiceColors(
    accent: Color(0xFF15803D),
    onAccent: Colors.white,
    soft: Color(0xFFDCFCE7),
    background: Color(0xFFF7FCF8),
    card: Color(0xFFECF9F0),
    border: Color(0xFFB7E4C7),
  );

  static const pharmacy = ZivoServiceColors(
    accent: Color(0xFF7C3AED),
    onAccent: Colors.white,
    soft: Color(0xFFEDE9FE),
    background: Color(0xFFFAF8FF),
    card: Color(0xFFF4F1FE),
    border: Color(0xFFD7CBFA),
  );

  static const cleaning = ZivoServiceColors(
    accent: Color(0xFF0F766E),
    onAccent: Colors.white,
    soft: Color(0xFFCCFBF1),
    background: Color(0xFFF7FCFB),
    card: Color(0xFFE9F9F6),
    border: Color(0xFFAFE3DA),
  );

  static ZivoServiceColors forId(ServiceId id) => switch (id) {
    ServiceId.food => food,
    ServiceId.grocery => grocery,
    ServiceId.pharmacy => pharmacy,
    ServiceId.cleaning => cleaning,
  };
}

class ZivoServiceTheme extends StatelessWidget {
  const ZivoServiceTheme({
    super.key,
    required this.serviceId,
    required this.child,
  });

  final ServiceId serviceId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ServiceThemes.forId(serviceId);
    final base = Theme.of(context);
    final scheme = base.colorScheme.copyWith(
      primary: colors.accent,
      onPrimary: colors.onAccent,
      primaryContainer: colors.soft,
      onPrimaryContainer: TwColors.text,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      secondaryContainer: colors.soft,
      onSecondaryContainer: TwColors.text,
      surface: colors.background,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.card,
      surfaceContainer: colors.card,
      surfaceContainerHigh: colors.soft,
      surfaceContainerHighest: colors.soft,
      outline: colors.border,
      outlineVariant: colors.border,
    );

    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: colors.background,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: colors.background,
          foregroundColor: TwColors.text,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: base.cardTheme.copyWith(
          color: colors.card,
          shadowColor: TwColors.slate900.withOpacityValue(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwRadius.xl),
            side: BorderSide(color: colors.border),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.onAccent,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: colors.accent,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: colors.card,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwRadius.xl),
            borderSide: BorderSide(color: colors.accent, width: 1.5),
          ),
        ),
        extensions: <ThemeExtension<dynamic>>[colors],
      ),
      child: child,
    );
  }
}

extension ZivoThemeContext on BuildContext {
  ZivoServiceColors get serviceColors =>
      Theme.of(this).extension<ZivoServiceColors>() ??
      ZivoServiceColors.platform;
}
