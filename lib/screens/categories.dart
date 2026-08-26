import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/service_module.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_misc.dart';
import '../widgets/app_scaffold.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Services',
      showBackButton: showBackButton,
      // A true one-column list rather than a fixed-aspect-ratio grid, so
      // each card sizes to its own content instead of overflowing at
      // narrow widths / large text scales.
      body: ListView.separated(
        padding: const EdgeInsets.all(TwSpacing.x5),
        itemCount: ServiceRegistry.modules.length,
        separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x5),
        itemBuilder: (context, index) {
          final module = ServiceRegistry.modules[index];
          // White card only ("one card per list") — the service accent is
          // confined to the 48px ServiceIconChip, never the card fill or
          // border.
          return OutlinedCard(
            child: InkWell(
              key: Key('services-${module.id.name}'),
              onTap: () => context.push(module.entryRoute),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZivoServiceTheme(
                    serviceId: module.id,
                    child: ServiceIconChip(icon: module.icon, iconSize: 26),
                  ),
                  const SizedBox(height: TwSpacing.rhythmDefault),
                  Text(
                    module.title,
                    textAlign: TextAlign.center,
                    style: TwText.fontBoldBase(),
                  ),
                  const SizedBox(height: TwSpacing.rhythmTight),
                  Text(
                    module.description,
                    textAlign: TextAlign.center,
                    style: TwText.textSm(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
