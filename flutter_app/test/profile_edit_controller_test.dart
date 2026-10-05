import 'dart:async';
import 'dart:convert';

import 'package:chowflow/features/auth/data/auth_service.dart';
import 'package:chowflow/features/profile/data/profile_repository.dart';
import 'package:chowflow/features/profile/models/customer_profile.dart';
import 'package:chowflow/features/profile/presentation/profile_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Same technique as settings_screen_test.dart/auth_service_test.dart: the
// implicit flow + a mocked http client establishes a real signed-in
// AuthService without any platform channel or network access, which
// updateEmail's tests need (AuthService isn't an interface, so there is no
// lighter-weight fake to substitute).
const _testAuthOptions = AuthClientOptions(
  authFlowType: AuthFlowType.implicit,
  autoRefreshToken: false,
);

Map<String, dynamic> _sessionJson({
  required String userId,
  required String email,
}) {
  final now = DateTime.now().toIso8601String();
  return {
    'access_token': 'mock-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'mock-refresh-token',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'email': email,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': now,
    },
  };
}

/// A signed-in [AuthService] backed by a mocked Supabase client. Passing
/// [httpClient] overrides the default handler (which just replies to every
/// request with a fresh session) -- the `updateEmail` tests below need a
/// handler that also answers the `PUT /auth/v1/user` request
/// [AuthService.updateEmail] sends.
Future<AuthService> _signedInAuthService({
  required String userId,
  required String email,
  http.Client? httpClient,
}) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-publishable-key',
    authOptions: _testAuthOptions,
    httpClient:
        httpClient ??
        MockClient((request) async {
          return http.Response(
            jsonEncode(_sessionJson(userId: userId, email: email)),
            200,
          );
        }),
  );
  final service = AuthService(client: client);
  await service.signInWithEmailPassword(email, 'a-strong-password');
  return service;
}

void main() {
  group('ProfileEditController.updateName', () {
    test(
      'rejects an empty first name without calling the repository',
      () async {
        final repository = _RecordingProfileRepository();
        final controller = ProfileEditController(profileRepository: repository);

        final result = await controller.updateName(
          firstName: '  ',
          lastName: 'Noor',
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

      final result = await controller.updateName(
        firstName: 'Amina',
        lastName: '',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains('Enter your last name.'));
      expect(repository.updateCalls, isEmpty);
    });

    test('trims and forwards only first/last name to the repository, returning '
        'its saved profile', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.updateName(
        firstName: '  Amina  ',
        lastName: ' Noor ',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile?.firstName, 'Amina');
      expect(controller.isSubmitting, isFalse);
      expect(controller.submissionError, isNull);
      expect(repository.updateCalls, hasLength(1));
      final call = repository.updateCalls.single;
      expect(call.firstName, 'Amina');
      expect(call.lastName, 'Noor');
      // Phone/dob were not part of this call, so they must stay unsent
      // rather than sent as null-that-means-clear.
      expect(call.phone, isNull);
      expect(call.dob, isNull);
    });

    test('surfaces a generic message when the repository throws', () async {
      final repository = _RecordingProfileRepository(
        error: StateError('network down'),
      );
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.updateName(
        firstName: 'Amina',
        lastName: 'Noor',
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

      final first = controller.updateName(firstName: 'Amina', lastName: 'Noor');
      final second = await controller.updateName(
        firstName: 'Amina',
        lastName: 'Noor',
      );

      expect(second.isSuccess, isFalse);
      expect(second.errors, isEmpty);
      repository.completeDelayed();
      final firstResult = await first;
      expect(firstResult.isSuccess, isTrue);
      expect(repository.updateCalls, hasLength(1));
    });
  });

  group('ProfileEditController.updatePhone', () {
    test(
      'rejects an empty phone number without calling the repository',
      () async {
        final repository = _RecordingProfileRepository();
        final controller = ProfileEditController(profileRepository: repository);

        final result = await controller.updatePhone('   ');

        expect(result.isSuccess, isFalse);
        expect(result.errors, contains('Enter your phone number.'));
        expect(repository.updateCalls, isEmpty);
      },
    );

    test('rejects an implausibly short phone number without calling the '
        'repository', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.updatePhone('123');

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains('Please enter a valid phone number.'));
      expect(repository.updateCalls, isEmpty);
    });

    test('trims and forwards only the phone number to the repository, '
        'returning its saved profile', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.updatePhone(' +252 61 234 5678 ');

      expect(result.isSuccess, isTrue);
      expect(repository.updateCalls, hasLength(1));
      final call = repository.updateCalls.single;
      expect(call.phone, '+252 61 234 5678');
      expect(call.firstName, isNull);
      expect(call.lastName, isNull);
      expect(call.dob, isNull);
    });

    test('surfaces a generic message when the repository throws', () async {
      final repository = _RecordingProfileRepository(
        error: StateError('network down'),
      );
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.updatePhone('+252 61 234 5678');

      expect(result.isSuccess, isFalse);
      expect(
        controller.submissionError,
        'Could not save your profile. Please try again.',
      );
    });
  });

  group('ProfileEditController.updateDob', () {
    test('rejects a date of birth in the future without calling the '
        'repository', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);
      final future = DateTime.now().add(const Duration(days: 1));

      final result = await controller.updateDob(future);

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains("Date of birth can't be in the future."));
      expect(repository.updateCalls, isEmpty);
    });

    test('forwards only the date of birth to the repository, returning its '
        'saved profile', () async {
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(profileRepository: repository);
      final dob = DateTime(1995, 6, 15);

      final result = await controller.updateDob(dob);

      expect(result.isSuccess, isTrue);
      expect(repository.updateCalls, hasLength(1));
      final call = repository.updateCalls.single;
      expect(call.dob, dob);
      expect(call.firstName, isNull);
      expect(call.lastName, isNull);
      expect(call.phone, isNull);
    });

    test('surfaces a generic message when the repository throws', () async {
      final repository = _RecordingProfileRepository(
        error: StateError('network down'),
      );
      final controller = ProfileEditController(profileRepository: repository);

      final result = await controller.updateDob(DateTime(1995, 6, 15));

      expect(result.isSuccess, isFalse);
      expect(
        controller.submissionError,
        'Could not save your profile. Please try again.',
      );
    });
  });

  group('ProfileEditController.updateEmail', () {
    test('rejects an empty email without calling AuthService', () async {
      final authService = await _signedInAuthService(
        userId: 'customer-1',
        email: 'amina@zivo.app',
      );
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(
        profileRepository: repository,
        authService: authService,
      );

      final result = await controller.updateEmail('   ');

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains('Enter your email address.'));
    });

    test(
      'rejects an invalid email format without calling AuthService',
      () async {
        final authService = await _signedInAuthService(
          userId: 'customer-1',
          email: 'amina@zivo.app',
        );
        final controller = ProfileEditController(
          profileRepository: _RecordingProfileRepository(),
          authService: authService,
        );

        final result = await controller.updateEmail('not-an-email');

        expect(result.isSuccess, isFalse);
        expect(result.errors, contains('Please enter a valid email address.'));
      },
    );

    test('rejects the unchanged email address (case-insensitively) without '
        'calling AuthService.updateEmail', () async {
      var updateEmailRequestSent = false;
      final authService = await _signedInAuthService(
        userId: 'customer-1',
        email: 'amina@zivo.app',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/user') {
            updateEmailRequestSent = true;
          }
          return http.Response(
            jsonEncode(
              _sessionJson(userId: 'customer-1', email: 'amina@zivo.app'),
            ),
            200,
          );
        }),
      );
      final controller = ProfileEditController(
        profileRepository: _RecordingProfileRepository(),
        authService: authService,
      );

      final result = await controller.updateEmail('AMINA@ZIVO.APP');

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains("That's already your email address."));
      expect(updateEmailRequestSent, isFalse);
    });

    test('trims and calls AuthService.updateEmail, returning success with no '
        'profile and without touching the profile repository', () async {
      http.Request? capturedRequest;
      final authService = await _signedInAuthService(
        userId: 'customer-1',
        email: 'amina@zivo.app',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/user') {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'id': 'customer-1',
                'aud': 'authenticated',
                'email': 'new@zivo.app',
                'app_metadata': <String, dynamic>{},
                'user_metadata': <String, dynamic>{},
                'created_at': DateTime.now().toIso8601String(),
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(
              _sessionJson(userId: 'customer-1', email: 'amina@zivo.app'),
            ),
            200,
          );
        }),
      );
      final repository = _RecordingProfileRepository();
      final controller = ProfileEditController(
        profileRepository: repository,
        authService: authService,
      );

      final result = await controller.updateEmail('  new@zivo.app  ');

      expect(result.isSuccess, isTrue);
      expect(result.profile, isNull);
      expect(repository.updateCalls, isEmpty);
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'PUT');
      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['email'], 'new@zivo.app');
    });

    test('maps a thrown error to a generic user-facing message', () async {
      final authService = await _signedInAuthService(
        userId: 'customer-1',
        email: 'amina@zivo.app',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/user') {
            throw Exception('network down');
          }
          return http.Response(
            jsonEncode(
              _sessionJson(userId: 'customer-1', email: 'amina@zivo.app'),
            ),
            200,
          );
        }),
      );
      final controller = ProfileEditController(
        profileRepository: _RecordingProfileRepository(),
        authService: authService,
      );

      final result = await controller.updateEmail('new@zivo.app');

      expect(result.isSuccess, isFalse);
      // A transport-level failure surfaces from gotrue as an
      // AuthRetryableFetchException (an AuthException with no specific
      // code), which describeAuthError maps to its generic default
      // branch rather than a raw exception message.
      expect(
        result.errors,
        contains('We could not complete that request. Please try again.'),
      );
      expect(controller.isSubmitting, isFalse);
    });

    test('a second call while one is in flight is a no-op', () async {
      final authService = await _signedInAuthService(
        userId: 'customer-1',
        email: 'amina@zivo.app',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/user') {
            return http.Response(
              jsonEncode({
                'id': 'customer-1',
                'aud': 'authenticated',
                'email': 'new@zivo.app',
                'app_metadata': <String, dynamic>{},
                'user_metadata': <String, dynamic>{},
                'created_at': DateTime.now().toIso8601String(),
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(
              _sessionJson(userId: 'customer-1', email: 'amina@zivo.app'),
            ),
            200,
          );
        }),
      );
      final controller = ProfileEditController(
        profileRepository: _RecordingProfileRepository(),
        authService: authService,
      );

      // _beginSubmit runs synchronously before the first `await` inside
      // updateEmail, so a second call issued without awaiting the first
      // observes isSubmitting == true already, same as _run's guard.
      final first = controller.updateEmail('new@zivo.app');
      final second = await controller.updateEmail('new@zivo.app');

      expect(second.isSuccess, isFalse);
      expect(second.errors, isEmpty);
      final firstResult = await first;
      expect(firstResult.isSuccess, isTrue);
    });
  });
}

class _RecordingProfileRepository implements ProfileRepository {
  _RecordingProfileRepository({this.error, this.delay = false});

  final Object? error;
  final bool delay;
  final List<
    ({String? firstName, String? lastName, String? phone, DateTime? dob})
  >
  updateCalls = [];
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
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dob,
  }) async {
    if (delay) {
      final completer = Completer<void>();
      _pending.add(() => completer.complete());
      await completer.future;
    }
    updateCalls.add((
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      dob: dob,
    ));
    if (error != null) {
      throw error!;
    }
    return CustomerProfile(
      id: 'customer-1',
      firstName: firstName ?? 'Amina',
      lastName: lastName ?? 'Noor',
      phone: phone ?? '+252 61 234 5678',
      dob: dob,
    );
  }

  @override
  Future<void> deleteAccount() async =>
      throw UnimplementedError('not exercised by this test');
}
