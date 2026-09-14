import 'dart:async';

import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/profile/presentation/profile_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileEditController.submit', () {
    test(
      'rejects an empty first name without calling the repository',
      () async {
        final repository = _RecordingProfileRepository();
        final controller = ProfileEditController(profileRepository: repository);

        final result = await controller.submit(
          firstName: '  ',
          lastName: 'Noor',
          phone: '+252 61 234 5678',
        );

        expect(result.isSuccess, isFalse);
        expect(result.errors, contains('Enter your first name.'));
        expect(controller.fieldErrors, contains('Enter your first name.'));
        expect(repository.updateCalls, isEmpty);
        expect(controller.isSubmitting, isFalse);
      },
    );

    test('rejects an empty last name without calling the repository', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.submit(
        firstName: 'Amina',
        lastName: '',
        phone: '',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains('Enter your last name.'));
      expect(repository.updateCalls, isEmpty);
    });

    test('accepts an empty phone number (optional field)', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.submit(
        firstName: 'Amina',
        lastName: 'Noor',
        phone: '   ',
      );

      expect(result.isSuccess, isTrue);
      expect(repository.updateCalls, hasLength(1));
      expect(repository.updateCalls.single.phone, '');
    });

    test('rejects an implausibly short phone number', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.submit(
        firstName: 'Amina',
        lastName: 'Noor',
        phone: '123',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains('Enter a valid phone number.'));
      expect(repository.updateCalls, isEmpty);
    });

    test('trims and forwards valid fields to the repository, returning its '
        'saved profile', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.submit(
        firstName: '  Amina  ',
        lastName: ' Noor ',
        phone: ' +252 61 234 5678 ',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile?.firstName, 'Amina');
      expect(controller.isSubmitting, isFalse);
      expect(controller.submissionError, isNull);
      expect(repository.updateCalls, hasLength(1));
      expect(repository.updateCalls.single.firstName, 'Amina');
      expect(repository.updateCalls.single.lastName, 'Noor');
      expect(repository.updateCalls.single.phone, '+252 61 234 5678');
    });

    test('surfaces a message when the repository throws', () async {
      final repository = _RecordingProfileRepository(
        error: StateError('network down'),
      );
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.submit(
        firstName: 'Amina',
        lastName: 'Noor',
        phone: '',
      );

      expect(result.isSuccess, isFalse);
      expect(controller.isSubmitting, isFalse);
      expect(
        controller.submissionError,
        'Could not save your profile. Please try again.',
      );
    });

    test('a second call while one is in flight is a no-op', () async {
      final repository = _RecordingProfileRepository(delay: true);
      final controller = ProfileEditController(profileRepository: repository);

      final first = controller.submit(
        firstName: 'Amina',
        lastName: 'Noor',
        phone: '',
      );
      final second = await controller.submit(
        firstName: 'Amina',
        lastName: 'Noor',
        phone: '',
      );

      expect(second.isSuccess, isFalse);
      expect(second.errors, isEmpty);
      repository.completeDelayed();
      final firstResult = await first;
      expect(firstResult.isSuccess, isTrue);
      expect(repository.updateCalls, hasLength(1));
    });
  });
}

class _RecordingProfileRepository implements ProfileRepository {
  _RecordingProfileRepository({this.error, this.delay = false});

  final Object? error;
  final bool delay;
  final List<({String firstName, String lastName, String phone})> updateCalls =
      [];
  final List<void Function()> _pending = [];

  void completeDelayed() {
    for (final complete in _pending) {
      complete();
    }
    _pending.clear();
  }

  @override
  Future<CustomerProfile?> fetchCurrentProfile() async =>
      throw UnimplementedError('not exercised by this test');

  @override
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    if (delay) {
      final completer = Completer<void>();
      _pending.add(() => completer.complete());
      await completer.future;
    }
    updateCalls.add((firstName: firstName, lastName: lastName, phone: phone));
    if (error != null) {
      throw error!;
    }
    return CustomerProfile(
      id: 'customer-1',
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
  }

  @override
  Future<void> deleteAccount() async =>
      throw UnimplementedError('not exercised by this test');
}
