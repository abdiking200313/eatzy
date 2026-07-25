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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TwText.textXl(),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(
            actionLabel,
            style: TwText.link(),
          ),
        ),
      ],
    );
  }
}
