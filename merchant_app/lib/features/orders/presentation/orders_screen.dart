import 'package:flutter/material.dart';

import '../../../widgets/stub_destination.dart';

/// Stub "Orders" destination (issue #132). The merchant order queue is
/// built out in the child issue that follows this scaffold (#134) -- this
/// is a real routed destination, not a TODO placeholder.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StubDestination(
      icon: Icons.receipt_long_outlined,
      title: 'Orders',
      message:
          'Incoming and past orders are coming soon. This is a '
          'placeholder destination for issue #134.',
    );
  }
}
