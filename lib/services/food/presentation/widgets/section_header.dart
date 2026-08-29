import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onPressed,
  }) : assert(
         (actionLabel == null) == (onPressed == null),
         'actionLabel and onPressed must either both be provided or both be null.',
       );

  final String title;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Expanded + ellipsis keeps this row overflow-free next to the
        // trailing action button at narrow widths / large text scales
        // (e.g. 320x640 @1.4x) without changing the header's styling.
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TwText.sectionLabel,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onPressed,
            child: Text(
              actionLabel!,
              style: TwText.link.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}
