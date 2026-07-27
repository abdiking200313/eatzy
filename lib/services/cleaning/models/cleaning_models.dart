class CleaningSpecialty {
  const CleaningSpecialty({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  factory CleaningSpecialty.fromMap(Map<String, dynamic> map) {
    return CleaningSpecialty(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'name'),
      description: _optionalString(map, 'description'),
    );
  }
}

class CleaningStayPlan {
  const CleaningStayPlan({
    required this.durationWeeks,
    required this.weeklyRate,
  });

  final int durationWeeks;
  final double weeklyRate;

  double get total => weeklyRate * durationWeeks;

  factory CleaningStayPlan.fromMap(Map<String, dynamic> map) {
    final durationWeeks = _requiredInt(map, 'duration_weeks');
    final weeklyRate = _requiredDouble(map, 'weekly_rate');
    if (!const {1, 2, 4}.contains(durationWeeks) || weeklyRate <= 0) {
      throw const FormatException('Invalid cleaner stay plan.');
    }
    return CleaningStayPlan(
      durationWeeks: durationWeeks,
      weeklyRate: weeklyRate,
    );
  }
}

class CleaningProfessional {
  const CleaningProfessional({
    required this.id,
    required this.displayName,
    required this.rating,
    required this.reviewCount,
    required this.headline,
    required this.bio,
    required this.city,
    required this.experienceYears,
    required this.languages,
    required this.specialties,
    required this.stayPlans,
    this.photoUrl,
  });

  final String id;
  final String displayName;
  final double rating;
  final int reviewCount;
  final String headline;
  final String bio;
  final String city;
  final int experienceYears;
  final List<String> languages;
  final List<CleaningSpecialty> specialties;
  final List<CleaningStayPlan> stayPlans;
  final String? photoUrl;

  bool offersSpecialty(String specialtyId) =>
      specialties.any((specialty) => specialty.id == specialtyId);

  bool offersPlan(CleaningStayPlan plan) => stayPlans.any(
    (candidate) =>
        candidate.durationWeeks == plan.durationWeeks &&
        candidate.weeklyRate == plan.weeklyRate,
  );

  double get startingWeeklyRate => stayPlans
      .map((plan) => plan.weeklyRate)
      .reduce((first, second) => first < second ? first : second);

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  factory CleaningProfessional.fromMap(
    Map<String, dynamic> map, {
    required List<CleaningSpecialty> specialties,
    required List<CleaningStayPlan> stayPlans,
  }) {
    final experienceYears = _requiredInt(map, 'years_experience');
    final reviewCount = _requiredInt(map, 'review_count');
    final languages = _requiredStringList(map, 'languages');
    if (experienceYears < 0 || reviewCount < 0 || stayPlans.isEmpty) {
      throw const FormatException('Invalid cleaner profile.');
    }
    return CleaningProfessional(
      id: _requiredString(map, 'id'),
      displayName: _requiredString(map, 'display_name'),
      rating: _requiredDouble(map, 'rating'),
      reviewCount: reviewCount,
      headline: _requiredString(map, 'headline'),
      bio: _requiredString(map, 'bio'),
      city: _requiredString(map, 'city'),
      experienceYears: experienceYears,
      languages: List.unmodifiable(languages),
      specialties: List.unmodifiable(specialties),
      stayPlans: List.unmodifiable(stayPlans),
      photoUrl: _nullableString(map, 'profile_image_url'),
    );
  }
}

class SomaliaAddress {
  const SomaliaAddress({required this.streetAddress, required this.city});

  final String streetAddress;
  final String city;

  String get formatted => '$streetAddress, $city, Somalia';
}

class CleaningBookingRequest {
  const CleaningBookingRequest({
    required this.professional,
    required this.specialty,
    required this.plan,
    required this.address,
    required this.startsAt,
    required this.instructions,
  });

  final CleaningProfessional professional;
  final CleaningSpecialty specialty;
  final CleaningStayPlan plan;
  final SomaliaAddress address;
  final DateTime startsAt;
  final String instructions;

  DateTime get endsAt => startsAt.add(Duration(days: plan.durationWeeks * 7));
  double get total => plan.total;
}

enum CleaningBookingStatus { demoConfirmed }

class CleaningBooking {
  const CleaningBooking({
    required this.id,
    required this.request,
    required this.cleaner,
    required this.status,
    required this.createdAt,
    this.isProduction = false,
  });

  final String id;
  final CleaningBookingRequest request;
  final CleaningProfessional cleaner;
  final CleaningBookingStatus status;
  final DateTime createdAt;
  final bool isProduction;

  double get total => request.total;

  String get statusLabel => switch (status) {
    CleaningBookingStatus.demoConfirmed => 'Confirmed',
  };
}

class CleaningBookingReceipt {
  const CleaningBookingReceipt({
    required this.bookingId,
    required this.professionalId,
    required this.professionalName,
    required this.createdAt,
  });

  final String bookingId;
  final String professionalId;
  final String professionalName;
  final DateTime createdAt;

  factory CleaningBookingReceipt.fromMap(Map<String, dynamic> map) {
    final createdAt = DateTime.tryParse(_requiredString(map, 'created_at'));
    if (createdAt == null) {
      throw const FormatException('Invalid cleaning booking creation time.');
    }
    return CleaningBookingReceipt(
      bookingId: _requiredString(map, 'booking_id'),
      professionalId: _requiredString(map, 'professional_id'),
      professionalName: _requiredString(map, 'professional_name'),
      createdAt: createdAt.toUtc(),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required cleaning field: $key');
  }
  return value;
}

String _optionalString(Map<String, dynamic> map, String key) {
  return map[key]?.toString().trim() ?? '';
}

String? _nullableString(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

double _requiredDouble(Map<String, dynamic> map, String key) {
  final value = map[key];
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('Invalid cleaning number: $key');
  }
  return parsed;
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Invalid cleaning integer: $key');
  }
  return parsed;
}

List<String> _requiredStringList(Map<String, dynamic> map, String key) {
  final raw = map[key];
  if (raw is! List) {
    throw FormatException('Invalid cleaning list: $key');
  }
  final values = raw
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (values.isEmpty) {
    throw FormatException('Missing required cleaning field: $key');
  }
  return values;
}
