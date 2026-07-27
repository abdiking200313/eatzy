import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/service_module.dart';
import '../config/theme.dart';
import '../widgets/app_scaffold.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Explore',
      showBackButton: false,
      body: ListView.separated(
        padding: const EdgeInsets.all(TwSpacing.x5),
        itemCount: ServiceRegistry.modules.length,
        separatorBuilder: (_, _) => const SizedBox(height: TwSpacing.x3),
        itemBuilder: (context, index) {
          final module = ServiceRegistry.modules[index];
          final colors = ServiceThemes.forId(module.id);
          return Card(
            color: colors.card,
            elevation: 0.6,
            shadowColor: TwColors.slate900.withOpacityValue(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TwRadius.xl),
              side: BorderSide(color: colors.border),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(TwSpacing.x3),
              onTap: () => context.push(module.entryRoute),
              leading: CircleAvatar(
                backgroundColor: colors.soft,
                child: Icon(module.icon, color: colors.accent),
              ),
              title: Text(module.title, style: TwText.fontBoldBase()),
              subtitle: Text(module.description),
              trailing: Icon(Icons.chevron_right, color: colors.accent),
            ),
          );
        },
      ),
    );
  }
}
