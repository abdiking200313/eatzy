import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/platform/activity/presentation/activity_controller.dart';
import 'package:chowflow/services/cleaning/data/cleaning_repository.dart';
import 'package:chowflow/services/cleaning/models/cleaning_models.dart';
import 'package:chowflow/services/cleaning/presentation/cleaning_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 27, 9);

  CleaningController buildController({ActivityController? activityController}) {
    return CleaningController(
      activityController: activityController,
      now: () => now,
      bookingIdFactory: () => 'cleaning-test-1',
    );
  }

  void completeValidDraft(CleaningController controller) {
    final cleaner = controller.professionals.first;
    controller
      ..selectProfessional(cleaner)
      ..selectSpecialty(cleaner.specialties.first)
      ..selectPlan(cleaner.stayPlans.first)
      ..selectCity('Mogadishu')
      ..setStreetAddress('Maka Al-Mukarama Road')
      ..setStartsAt(now.add(const Duration(days: 1, hours: 1)))
      ..setInstructions('Please call when you arrive.');
  }

  test('validates every required arrangement choice', () {
    final controller = buildController();

    expect(controller.validate(), isFalse);
    expect(
      controller.validationErrors.keys,
      containsAll([
        'professional',
        'specialty',
        'plan',
        'city',
        'address',
        'startsAt',
      ]),
    );
    expect(controller.validationErrors, isNot(contains('instructions')));
  });

  test('rejects past times and overly long instructions', () {
    final controller = buildController();
    completeValidDraft(controller);
    controller
      ..setStartsAt(now.subtract(const Duration(minutes: 1)))
      ..setInstructions('x' * (CleaningController.maxInstructionsLength + 1));

    expect(controller.validate(), isFalse);
    expect(controller.validationErrors['startsAt'], contains('future'));
    expect(
      controller.validationErrors['instructions'],
      contains('${CleaningController.maxInstructionsLength}'),
    );
  });

  test(
    'confirms the explicitly selected cleaner and records activity',
    () async {
      final activityController = ActivityController();
      final controller = buildController(
        activityController: activityController,
      );
      completeValidDraft(controller);

      final booking = await controller.confirmBooking();

      expect(booking, isNotNull);
      expect(booking!.cleaner.displayName, 'Amina Hassan');
      expect(booking.request.plan.durationWeeks, 1);
      expect(booking.total, 165);
      expect(booking.isProduction, isFalse);
      expect(booking.status, CleaningBookingStatus.demoConfirmed);
      expect(activityController.items, hasLength(1));
      expect(activityController.items.single.serviceId, ServiceId.cleaning);
      expect(activityController.items.single.amount, 165);
      expect(activityController.items.single.detailsRoute, '/cleaning');
    },
  );

  test('seeded repository does not replace a chosen busy cleaner', () {
    final repository = SeededCleaningRepository();
    final cleaner = repository.getProfessionals().first;
    final request = CleaningBookingRequest(
      professional: cleaner,
      specialty: cleaner.specialties.first,
      plan: cleaner.stayPlans.first,
      address: const SomaliaAddress(
        streetAddress: 'Airport Road',
        city: 'Mogadishu',
      ),
      startsAt: DateTime(2026, 7, 28, 10),
      instructions: '',
    );

    final first = repository.createBooking(
      id: 'one',
      request: request,
      createdAt: now,
    );

    expect(first.cleaner.id, cleaner.id);
    expect(
      () =>
          repository.createBooking(id: 'two', request: request, createdAt: now),
      throwsA(isA<NoCleanerAvailableException>()),
    );
  });

  test('back-to-back arrangements do not overlap', () {
    final repository = SeededCleaningRepository();
    final cleaner = repository.getProfessionals().first;
    final firstRequest = CleaningBookingRequest(
      professional: cleaner,
      specialty: cleaner.specialties.first,
      plan: cleaner.stayPlans.first,
      address: const SomaliaAddress(
        streetAddress: 'Airport Road',
        city: 'Mogadishu',
      ),
      startsAt: DateTime(2026, 7, 28, 10),
      instructions: '',
    );
    final secondRequest = CleaningBookingRequest(
      professional: cleaner,
      specialty: cleaner.specialties.first,
      plan: cleaner.stayPlans.first,
      address: firstRequest.address,
      startsAt: firstRequest.endsAt,
      instructions: '',
    );

    repository.createBooking(id: 'one', request: firstRequest, createdAt: now);
    final second = repository.createBooking(
      id: 'two',
      request: secondRequest,
      createdAt: now,
    );

    expect(second.cleaner.id, cleaner.id);
  });
}
