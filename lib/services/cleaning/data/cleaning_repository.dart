import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cleaning_models.dart';

abstract interface class CleaningRepository {
  List<CleaningProfessional> getProfessionals();

  void resetSessionState();

  CleaningBooking createBooking({
    required String id,
    required CleaningBookingRequest request,
    required DateTime createdAt,
  });
}

abstract interface class CleaningCatalogRepository {
  Future<List<CleaningProfessional>> fetchProfessionals();
}

abstract interface class CleaningBookingRepository {
  Future<CleaningBookingReceipt> placeBooking(CleaningBookingRequest request);
}

class NoCleanerAvailableException implements Exception {
  const NoCleanerAvailableException();

  @override
  String toString() => 'The selected cleaner is unavailable for those dates.';
}

class SeededCleaningRepository implements CleaningRepository {
  SeededCleaningRepository({List<CleaningProfessional>? cleaners})
    : _cleaners = cleaners ?? _seedCleaners;

  final List<CleaningProfessional> _cleaners;
  final List<CleaningBooking> _bookings = [];

  static const _everydayCare = CleaningSpecialty(
    id: 'everyday-care',
    name: 'Everyday home care',
    description: 'Daily tidying, floors, kitchens, and bathrooms.',
  );
  static const _deepCleaning = CleaningSpecialty(
    id: 'deep-cleaning',
    name: 'Deep cleaning',
    description: 'Detailed kitchen, bathroom, and full-home cleaning.',
  );
  static const _laundry = CleaningSpecialty(
    id: 'laundry-organization',
    name: 'Laundry & organization',
    description: 'Laundry, wardrobes, and keeping the home organized.',
  );
  static const _kitchenCare = CleaningSpecialty(
    id: 'kitchen-care',
    name: 'Kitchen care',
    description: 'Meal-area hygiene, dishes, and kitchen organization.',
  );

  static const List<CleaningProfessional> _seedCleaners = [
    CleaningProfessional(
      id: 'cleaner-amina',
      displayName: 'Amina Hassan',
      rating: 4.9,
      reviewCount: 38,
      headline: 'Experienced family-home cleaner',
      bio:
          'Reliable household support with a careful eye for kitchens, '
          'laundry, and family homes.',
      city: 'Mogadishu',
      experienceYears: 8,
      languages: ['Somali', 'English'],
      specialties: [_everydayCare, _deepCleaning, _laundry],
      stayPlans: [
        CleaningStayPlan(durationWeeks: 1, weeklyRate: 165),
        CleaningStayPlan(durationWeeks: 2, weeklyRate: 155),
        CleaningStayPlan(durationWeeks: 4, weeklyRate: 145),
      ],
    ),
    CleaningProfessional(
      id: 'cleaner-hodan',
      displayName: 'Hodan Ali',
      rating: 4.8,
      reviewCount: 27,
      headline: 'Consistent care for busy households',
      bio:
          'Warm, consistent cleaner specializing in regular home care and '
          'detailed kitchen cleaning.',
      city: 'Hargeisa',
      experienceYears: 6,
      languages: ['Somali', 'Arabic'],
      specialties: [_everydayCare, _deepCleaning, _kitchenCare],
      stayPlans: [
        CleaningStayPlan(durationWeeks: 1, weeklyRate: 145),
        CleaningStayPlan(durationWeeks: 2, weeklyRate: 138),
        CleaningStayPlan(durationWeeks: 4, weeklyRate: 130),
      ],
    ),
    CleaningProfessional(
      id: 'cleaner-abdi',
      displayName: 'Abdi Nur',
      rating: 4.7,
      reviewCount: 19,
      headline: 'Home organization and laundry specialist',
      bio:
          'Organized long-stay home helper experienced with laundry, '
          'shopping support, and larger households.',
      city: 'Bosaso',
      experienceYears: 5,
      languages: ['Somali', 'English'],
      specialties: [_everydayCare, _laundry],
      stayPlans: [
        CleaningStayPlan(durationWeeks: 1, weeklyRate: 135),
        CleaningStayPlan(durationWeeks: 2, weeklyRate: 128),
        CleaningStayPlan(durationWeeks: 4, weeklyRate: 120),
      ],
    ),
  ];

  @override
  List<CleaningProfessional> getProfessionals() => List.unmodifiable(_cleaners);

  @override
  void resetSessionState() => _bookings.clear();

  @override
  CleaningBooking createBooking({
    required String id,
    required CleaningBookingRequest request,
    required DateTime createdAt,
  }) {
    final cleaner = _cleaners
        .where((candidate) => candidate.id == request.professional.id)
        .firstOrNull;
    if (cleaner == null ||
        !cleaner.offersSpecialty(request.specialty.id) ||
        !cleaner.offersPlan(request.plan) ||
        _hasConflict(cleaner.id, request)) {
      throw const NoCleanerAvailableException();
    }

    final booking = CleaningBooking(
      id: id,
      request: request,
      cleaner: cleaner,
      status: CleaningBookingStatus.demoConfirmed,
      createdAt: createdAt,
    );
    _bookings.add(booking);
    return booking;
  }

  bool _hasConflict(String cleanerId, CleaningBookingRequest request) {
    return _bookings.any((booking) {
      if (booking.cleaner.id != cleanerId) {
        return false;
      }
      return request.startsAt.isBefore(booking.request.endsAt) &&
          request.endsAt.isAfter(booking.request.startsAt);
    });
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

class SupabaseCleaningCatalogRepository implements CleaningCatalogRepository {
  const SupabaseCleaningCatalogRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<CleaningProfessional>> fetchProfessionals() async {
    final results = await Future.wait<dynamic>([
      _client
          .from('cleaning_professionals')
          .select(
            'id, display_name, rating, review_count, headline, bio, city, '
            'years_experience, languages, profile_image_url',
          )
          .eq('is_active', true)
          .order('rating', ascending: false),
      _client
          .from('cleaning_specialties')
          .select('id, name, description')
          .eq('is_active', true)
          .order('sort_order'),
      _client
          .from('cleaning_professional_specialties')
          .select('professional_id, specialty_id'),
      _client
          .from('cleaning_professional_stay_plans')
          .select('professional_id, duration_weeks, weekly_rate')
          .eq('is_active', true)
          .order('duration_weeks'),
    ]);
    final professionalRows = _mapRows(results[0], 'cleaning professionals');
    final specialties = {
      for (final row in _mapRows(results[1], 'cleaning specialties'))
        _requiredValue(row, 'id'): CleaningSpecialty.fromMap(row),
    };
    final specialtiesByProfessional = <String, List<CleaningSpecialty>>{};
    for (final row in _mapRows(results[2], 'cleaner specialties')) {
      final specialty = specialties[_requiredValue(row, 'specialty_id')];
      if (specialty != null) {
        specialtiesByProfessional
            .putIfAbsent(_requiredValue(row, 'professional_id'), () => [])
            .add(specialty);
      }
    }
    final plansByProfessional = <String, List<CleaningStayPlan>>{};
    for (final row in _mapRows(results[3], 'cleaner stay plans')) {
      plansByProfessional
          .putIfAbsent(_requiredValue(row, 'professional_id'), () => [])
          .add(CleaningStayPlan.fromMap(row));
    }

    return List.unmodifiable(
      professionalRows.map((row) {
        final id = _requiredValue(row, 'id');
        return CleaningProfessional.fromMap(
          row,
          specialties: specialtiesByProfessional[id] ?? const [],
          stayPlans: plansByProfessional[id] ?? const [],
        );
      }),
    );
  }
}

class SupabaseCleaningBookingRepository implements CleaningBookingRepository {
  const SupabaseCleaningBookingRepository({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<CleaningBookingReceipt> placeBooking(
    CleaningBookingRequest request,
  ) async {
    final response = await _client.rpc(
      'place_long_stay_cleaning_booking',
      params: {
        'p_professional_id': request.professional.id,
        'p_specialty_id': request.specialty.id,
        'p_duration_weeks': request.plan.durationWeeks,
        'p_city': request.address.city.trim(),
        'p_street_address': request.address.streetAddress.trim(),
        'p_starts_at': _somaliaWallTimeToUtc(
          request.startsAt,
        ).toIso8601String(),
        'p_instructions': request.instructions.trim(),
      },
    );

    final row = switch (response) {
      final Map value => Map<String, dynamic>.from(value),
      final List value when value.length == 1 && value.single is Map =>
        Map<String, dynamic>.from(value.single as Map),
      _ => throw const FormatException(
        'The cleaning booking RPC returned an invalid result.',
      ),
    };
    return CleaningBookingReceipt.fromMap(row);
  }
}

DateTime _somaliaWallTimeToUtc(DateTime value) {
  if (value.isUtc) {
    return value;
  }
  return DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour - 3,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

List<Map<String, dynamic>> _mapRows(Object? value, String label) {
  if (value is! List) {
    throw FormatException('Expected a list of $label.');
  }
  return value
      .map((row) {
        if (row is! Map) {
          throw FormatException('Invalid $label row.');
        }
        return Map<String, dynamic>.from(row);
      })
      .toList(growable: false);
}

String _requiredValue(Map<String, dynamic> row, String key) {
  final value = row[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required cleaning field: $key');
  }
  return value;
}
