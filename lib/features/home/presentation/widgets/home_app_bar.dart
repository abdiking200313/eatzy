import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/zivo_logo.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    this.onNotificationsPressed,
  });

  final VoidCallback? onNotificationsPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: TwColors.bg,
      elevation: 0,
      title: const ZivoLogo(height: 34),
      actions: [
        IconButton(
          onPressed: onNotificationsPressed,
          icon: const Icon(
            Icons.notifications_none,
            color: TwColors.primary,
          ),
        ),
        const SizedBox(width: TwSpacing.x2),
      ],
    );
  }
}
