import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.contactLabel,
    this.isLoading = false,
  });

  final String displayName;
  final String contactLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.serviceColors;
    final textTheme = Theme.of(context).textTheme;
    return OutlinedCard(
      padding: const EdgeInsets.all(TwSpacing.x4),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.soft,
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 32,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading ? 'Loading profile…' : displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: TwSpacing.x1),
                Row(
                  children: [
                    Icon(
                      Icons.contact_phone_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: TwSpacing.x2),
                    Expanded(
                      child: Text(
                        contactLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
