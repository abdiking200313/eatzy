import 'package:flutter/material.dart';

import '../../../../config/theme.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: TwColors.primary,
          ),
          child: const Icon(Icons.person, size: 55, color: TwColors.text),
        ),
        const SizedBox(width: TwSpacing.x5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Amara Johnson', style: TwText.text2xl()),
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: TwColors.blue400, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text('amara@example.com', style: TwText.textSm()),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: TwColors.primary.withOpacityValue(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: TwColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Gold Member',
                    style: TextStyle(
                      color: TwColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
