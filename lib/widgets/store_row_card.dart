import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'app_cards.dart';
import 'app_misc.dart';

/// A tappable store/restaurant row on a store-list screen: a photo
/// thumbnail (or [fallbackIcon] tile when there's none), the store's name,
/// one or more muted subtitle lines, an optional trailing caption below
/// them (e.g. grocery's product count), and a trailing chevron. Shared by
/// food's restaurant list, grocery's store list, and pharmacy's store list
/// so the three verticals' store rows read as one consistent pattern.
class StoreRowCard extends StatelessWidget {
  const StoreRowCard({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.name,
    this.subtitleLines = const [],
    this.subtitleMaxLines = 1,
    this.caption,
    required this.onTap,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final String name;

  /// Extra muted lines under the name, e.g. a description or address.
  /// Callers filter out blank values before passing them in.
  final List<String> subtitleLines;
  final int subtitleMaxLines;

  /// A trailing muted caption below the subtitle lines, e.g. grocery's
  /// "N products" count.
  final String? caption;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      onTap: onTap,
      child: Row(
        children: [
          PhotoThumbnail(
            imageUrl: imageUrl,
            fallback: ServiceIconChip(icon: fallbackIcon, iconSize: 28),
          ),
          const SizedBox(width: TwSpacing.rhythmDefault),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TwText.fontBoldBase,
                ),
                for (final line in subtitleLines) ...[
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Text(
                    line,
                    maxLines: subtitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TwText.textSm.copyWith(color: TwColors.textMuted),
                  ),
                ],
                if (caption != null) ...[
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Text(
                    caption!,
                    style: TwText.textXs.copyWith(color: TwColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: TwSpacing.x2),
          const Icon(Icons.chevron_right_rounded, color: TwColors.textMuted),
        ],
      ),
    );
  }
}
