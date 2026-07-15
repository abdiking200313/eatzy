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
    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(backgroundImage: imageProvider, radius: radius),
      placeholder: (context, url) => CircleAvatar(radius: radius),
      errorWidget: (context, url, error) => CircleAvatar(radius: radius),
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
          Text(
            label,
            style: TwText.textXs().copyWith(color: fg, fontSize: fontSize),
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
    final labelStyle = isBold ? TwText.fontBoldBase() : TwText.textSm();
    final valueStyle = isBold
        ? TwText.fontBoldBase().copyWith(color: TwColors.primary)
        : TwText.fontBoldSm();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}
