import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onPressed;

  /// Tap height of the action link.
  static const double _tapHeight = 44;

  @override
  Widget build(BuildContext context) {
    // The gaps above and below are measured from the title text. The link
    // is taller than the title (44px tap area), so the part of it that
    // sticks out past the title is taken out of those gaps instead of
    // being added to them.
    const style = TwText.sectionTitle;
    final titleHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    final overhang = ((_tapHeight - titleHeight) / 2).clamp(
      0.0,
      TwSpacing.headerToContent,
    );
    return Padding(
      padding: EdgeInsets.only(
        top: TwSpacing.sectionGap - overhang,
        bottom: TwSpacing.headerToContent - overhang,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(_tapHeight, _tapHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
