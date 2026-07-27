import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/models/activity_item.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/platform/activity/presentation/activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity controller keeps newest records first and replaces IDs', () {
    final controller = ActivityController();
    final older = DateTime(2026, 7, 1);
    final newer = DateTime(2026, 7, 2);

    controller.record(
      ActivityItem(
        id: 'same',
        serviceId: ServiceId.food,
        title: 'Food order',
        status: 'Confirmed',
        occurredAt: older,
        amount: 10,
        detailsRoute: '/food',
      ),
    );
    controller.record(
      ActivityItem(
        id: 'grocery',
        serviceId: ServiceId.grocery,
        title: 'Grocery order',
        status: 'Confirmed',
        occurredAt: newer,
        amount: 20,
        detailsRoute: '/grocery',
      ),
    );
    controller.record(
      ActivityItem(
        id: 'same',
        serviceId: ServiceId.food,
        title: 'Updated food order',
        status: 'Ready',
        occurredAt: newer.add(const Duration(hours: 1)),
        amount: 12,
        detailsRoute: '/food',
      ),
    );

    expect(controller.items.map((item) => item.id), ['same', 'grocery']);
    expect(controller.items.first.status, 'Ready');
  });

  testWidgets('activity screen renders unified service records', (
    tester,
  ) async {
    final controller = ActivityController()
      ..record(
        ActivityItem(
          id: 'cleaning-1',
          serviceId: ServiceId.cleaning,
          title: 'Deep clean',
          status: 'MVP confirmed',
          occurredAt: DateTime.utc(2026, 7, 27),
          amount: 54,
          detailsRoute: '',
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: ActivityScreen(controller: controller)),
    );

    expect(find.text('Deep clean'), findsOneWidget);
    expect(find.text(r'$54.00'), findsOneWidget);
    expect(find.text('MVP confirmed'), findsOneWidget);
  });
}
