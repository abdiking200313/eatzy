import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_search_bar.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onSearch,
    required this.onNotifications,
    required this.onSettings,
  });

  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TwColors.primaryGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(TwRadius.hero),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.x5,
            TwSpacing.x2_5,
            TwSpacing.x3,
            TwSpacing.x6,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'zivo',
                    style: TwText.textXl.copyWith(
                      color: TwColors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: onNotifications,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: TwColors.white,
                    ),
                  ),
                  const SizedBox(width: TwSpacing.iconButtonGap),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: onSettings,
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: TwColors.white,
                    ),
                  ),
                ],
              ),
              // 18: literal per the "1a" spec's search-field-below-top-bar gap
              // (no token at this value).
              const SizedBox(height: 18),
              AppSearchBar(
                hintText: 'Search restaurants, stores...',
                onTap: onSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
