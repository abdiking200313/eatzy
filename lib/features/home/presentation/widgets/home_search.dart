import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';

class HomeSearch extends StatelessWidget {
  const HomeSearch({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const OutlinedCard(
      backgroundColor: Colors.white,
      borderRadius: 50,
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: TwColors.borderStrong,
          ),
          SizedBox(width: TwSpacing.x4),
          Expanded(
            child: Text(
              'Search restaurants...',
              style: TextStyle(color: TwColors.borderStrong),
            ),
          ),
        ],
      ),
    );
  }
}
