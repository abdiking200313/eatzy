import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/cleaning/models/cleaning_models.dart';
import 'package:chowflow/services/cleaning/presentation/cleaning_booking_screen.dart';
import 'package:chowflow/services/cleaning/presentation/cleaning_controller.dart';
import 'package:chowflow/services/cleaning/presentation/cleaning_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 27, 9);

  CleaningController buildController() => CleaningController(
    activityController: ActivityController(),
    now: () => now,
    bookingIdFactory: () => 'cleaning-widget-test',
  );

  testWidgets('cleaning home presents cleaner marketplace profiles', (
    tester,
  ) async {
    final controller = buildController();
    CleaningProfessional? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: CleaningHomeScreen(
          controller: controller,
          onChoose: (cleaner) => chosen = cleaner,
        ),
      ),
    );

    expect(find.text('Choose your cleaner'), findsOneWidget);
    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(find.text('Deep cleaning'), findsWidgets);
    expect(find.text(r'$145.00/week'), findsOneWidget);
    expect(find.textContaining('No payment taken'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Choose cleaner').first);
    await tester.pump();

    expect(chosen?.id, 'cleaner-amina');
    expect(controller.selectedProfessional?.id, 'cleaner-amina');
  });

  testWidgets('cleaner profiles stay overflow-free on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: CleaningHomeScreen(controller: buildController()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrangement form shows validation feedback', (tester) async {
    final controller = buildController();

    await tester.pumpWidget(
      MaterialApp(home: CleaningBookingScreen(controller: controller)),
    );

    await tester.scrollUntilVisible(
      find.text('Request arrangement'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Request arrangement'));
    await tester.pump();

    expect(find.text('Choose a start date and time.'), findsOneWidget);

    await tester.fling(find.byType(ListView), const Offset(0, 1400), 1200);
    await tester.pumpAndSettle();

    expect(find.text('Choose a cleaner.'), findsOneWidget);
    expect(find.text('Choose one of their specialties.'), findsOneWidget);
    expect(find.text('Choose an arrangement length.'), findsOneWidget);
    expect(find.text('Choose a city in Somalia.'), findsOneWidget);
  });

  testWidgets('confirmation keeps the selected cleaner and weekly total', (
    tester,
  ) async {
    final controller = buildController();
    final cleaner = controller.professionals.first;
    controller
      ..selectProfessional(cleaner)
      ..selectSpecialty(cleaner.specialties.first)
      ..selectPlan(cleaner.stayPlans.first)
      ..selectCity('Mogadishu')
      ..setStreetAddress('Maka Al-Mukarama Road')
      ..setStartsAt(now.add(const Duration(days: 1, hours: 1)))
      ..setInstructions('Please call on arrival.');
    await controller.confirmBooking();

    await tester.pumpWidget(
      MaterialApp(home: CleaningBookingScreen(controller: controller)),
    );

    expect(find.text('Arrangement requested'), findsOneWidget);
    expect(find.textContaining('Amina Hassan'), findsOneWidget);
    expect(find.textContaining('no payment was taken'), findsOneWidget);
    expect(find.textContaining(r'$165.00 estimated total'), findsOneWidget);
  });
}
