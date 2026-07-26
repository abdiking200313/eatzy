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
        Text(title, style: TwText.textXl()),
        if (actionLabel != null)
          TextButton(
            onPressed: onPressed,
            child: Text(actionLabel!, style: TwText.link()),
          ),
      ],
    );
  }
}
