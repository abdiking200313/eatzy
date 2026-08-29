import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

/// A circular avatar that loads an image from the network with a graceful
/// fallback while loading / on error.
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({super.key, required this.imageUrl, this.radius = 25});

  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // Decode at roughly the rendered diameter (radius * 2) scaled for
    // device pixel density, not at the source image's native resolution.
    // Capped at 3x since a wider cap buys no visible sharpness on a
    // circle this small while still inflating decode memory.
    final cacheScale = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final cacheDiameter = (radius * 2 * cacheScale).round();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      memCacheWidth: cacheDiameter,
      memCacheHeight: cacheDiameter,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(backgroundImage: imageProvider, radius: radius),
      placeholder: (context, url) => CircleAvatar(radius: radius),
      errorWidget: (context, url, error) => CircleAvatar(radius: radius),
    );
  }
}

/// The one place a per-service accent color is allowed to appear outside a
/// button: a fixed 48x48 rounded chip holding an icon. Cards, list rows,
/// and section headers must stay on the neutral tokens and use this chip
/// (with a [ZivoServiceColors] accent, or an explicit override) instead of
/// tinting their own background/border.
class ServiceIconChip extends StatelessWidget {
  const ServiceIconChip({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
    this.borderRadius = TwRadius.lg,
    this.iconSize = 24,
  });

  static const double size = 48;

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? palette.accent,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, size: iconSize, color: foreground ?? palette.onAccent),
    );
  }
}

/// A small pill-shaped status indicator (e.g. "On the way", "Delivered").
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize = 12,
    this.icon,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? TwColors.primaryAccent;
    final fg = foregroundColor ?? TwColors.blue900;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TwSpacing.x3,
        vertical: TwSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TwRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: fontSize + 2),
            const SizedBox(width: TwSpacing.x1),
          ],
          // Flexible + ellipsis lets the pill shrink gracefully instead of
          // overflowing when its parent gives it a tight width (e.g. a
          // narrow screen at a large text scale).
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TwText.textXs.copyWith(color: fg, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label/value row used in order summary blocks.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    // The bold/total row intentionally uses the fixed platform primary
    // rather than `Theme.of(context).colorScheme.primary` — under a
    // `ZivoServiceTheme` that scheme slot resolves to the per-service
    // accent, which would break the "accent confined to the 48px icon
    // chip" redesign rule for every cart/checkout summary using this row.
    final labelStyle = isBold ? TwText.fontBoldBase : TwText.textSm;
    final valueStyle = isBold
        ? TwText.fontBoldBase.copyWith(color: TwColors.primary)
        : TwText.fontBoldSm;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: TwSpacing.x3),
        Text(value, style: valueStyle),
      ],
    );
  }
}
