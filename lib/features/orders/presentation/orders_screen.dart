import 'package:flutter/material.dart';

import '../../../platform/activity/presentation/activity_controller.dart';
import '../../../platform/activity/presentation/activity_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key, this.activityController});

  final ActivityController? activityController;

  @override
  Widget build(BuildContext context) {
    return ActivityScreen(controller: activityController, title: 'Orders');
  }
}
