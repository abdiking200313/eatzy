import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/service_module.dart';
import '../config/theme.dart';
import '../widgets/app_cards.dart';
import '../widgets/app_scaffold.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Services',
      showBackButton: showBackButton,
      body: Padding(
        padding: const EdgeInsets.all(TwSpacing.x5),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: TwSpacing.x5,
            mainAxisSpacing: TwSpacing.x5,
            childAspectRatio: 1.4,
          ),
          itemCount: ServiceRegistry.modules.length,
          itemBuilder: (context, index) {
            final module = ServiceRegistry.modules[index];
            final colors = ServiceThemes.forId(module.id);
            return OutlinedCard(
              backgroundColor: colors.card,
              borderColor: colors.border,
              borderRadius: 16,
              child: InkWell(
                key: Key('services-${module.id.name}'),
                onTap: () => context.push(module.entryRoute),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.soft,
                        borderRadius: BorderRadius.circular(TwRadius.xl),
                      ),
                      child: Icon(module.icon, color: colors.accent, size: 30),
                    ),
                    const SizedBox(height: TwSpacing.x3),
                    Text(
                      module.title,
                      textAlign: TextAlign.center,
                      style: TwText.fontBoldBase(),
                    ),
                    const SizedBox(height: TwSpacing.x2),
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
      ),
    );
  }
}
