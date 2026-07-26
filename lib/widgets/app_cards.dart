import 'package:flutter/material.dart';
//import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

/// A neutral, outlined card used across screens. Defaults to the
/// [TwColors.cardMuted] background with an outline.
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TwSpacing.x5),
    this.borderRadius = TwRadius.lg,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius = BorderRadius.circular(borderRadius);
    final content = Padding(padding: padding, child: child);

    return Material(
      color: backgroundColor ?? TwColors.cardMuted,
      shape: RoundedRectangleBorder(
        borderRadius: resolvedBorderRadius,
        side: BorderSide(
          color: borderColor ?? TwColors.borderStrong,
          width: borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: resolvedBorderRadius,
              child: content,
            ),
    );
  }
}

/// A large, pill-shaped, gradient action button with optional icon and
/// label. Used for primary CTAs such as "Get Started" or "Checkout".
class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.padding = const EdgeInsets.symmetric(
      vertical: TwSpacing.x5,
      horizontal: TwSpacing.x5,
    ),
    this.borderRadius = 50,
    this.fontSize,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final bool fullWidth;
  final EdgeInsets padding;
  final double borderRadius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: fullWidth ? double.infinity : null,
      padding: padding,
      decoration: BoxDecoration(
        gradient: TwColors.primaryGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: TwColors.primary.withOpacityValue(0.3),
            blurRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TwText.button().copyWith(fontSize: fontSize)),
          if (icon != null) ...[const SizedBox(width: TwSpacing.x2), icon!],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: button,
      ),
    );
  }
}

/// A rounded solid-color primary button (used for less prominent actions).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.foregroundColor = Colors.white,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final Color? color;
  final Color foregroundColor;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: TwSpacing.x5),
      decoration: BoxDecoration(
        color: color ?? TwColors.primary,
        borderRadius: BorderRadius.circular(TwRadius.lg),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TwText.button().copyWith(color: foregroundColor)),
          if (icon != null) ...[const SizedBox(width: TwSpacing.x2), icon!],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(TwRadius.lg),
        child: button,
      ),
    );
  }
}
