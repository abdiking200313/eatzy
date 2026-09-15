import 'package:flutter/material.dart';

import '../../../widgets/stub_destination.dart';

/// Stub "My Store" destination (issue #132). Catalog/store-management
/// screens are built out in the child issue that follows this scaffold
/// (#133) -- this is a real routed destination, not a TODO placeholder.
class MyStoreScreen extends StatelessWidget {
  const MyStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StubDestination(
      icon: Icons.storefront_outlined,
      title: 'My Store',
      message:
          'Catalog and store management are coming soon. This is a '
          'placeholder destination for issue #133.',
    );
  }
}
