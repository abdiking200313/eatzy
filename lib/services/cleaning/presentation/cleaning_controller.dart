import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/service_module.dart';
import '../../../platform/activity/models/activity_item.dart';
import '../../../platform/activity/presentation/activity_controller.dart';
import '../data/cleaning_repository.dart';
import '../models/cleaning_models.dart';

class CleaningController extends ChangeNotifier {
  CleaningController({
    CleaningRepository? repository,
    CleaningCatalogRepository? catalogRepository,
    CleaningBookingRepository? bookingRepository,
    ActivityController? activityController,
    DateTime Function()? now,
    String Function()? bookingIdFactory,
  }) : _repository = repository ?? SeededCleaningRepository(),
       _catalogRepository = catalogRepository,
       _bookingRepository = bookingRepository,
       _activityController = activityController ?? ActivityController.instance,
       _now = now ?? DateTime.now,
       _bookingIdFactory =
           bookingIdFactory ??
           (() => 'cleaning-${DateTime.now().microsecondsSinceEpoch}') {
    _professionals.addAll(_repository.getProfessionals());
  }

  static final CleaningController instance = () {
    final client = Supabase.instance.client;
    return CleaningController(
      repository: SeededCleaningRepository(cleaners: const []),
      catalogRepository: SupabaseCleaningCatalogRepository(client: client),
      bookingRepository: SupabaseCleaningBookingRepository(client: client),
    )..load();
  }();

  static const supportedCities = <String>[
    'Mogadishu',
    'Hargeisa',
    'Bosaso',
    'Kismayo',
    'Garowe',
    'Baidoa',
  ];
  static const maxInstructionsLength = 300;

  final CleaningRepository _repository;
  final CleaningCatalogRepository? _catalogRepository;
  final CleaningBookingRepository? _bookingRepository;
  final ActivityController _activityController;
  final DateTime Function() _now;
  final String Function() _bookingIdFactory;
  final List<CleaningProfessional> _professionals = [];

  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isSubmitting = false;
  String? _loadError;
  CleaningProfessional? _selectedProfessional;
  CleaningSpecialty? _selectedSpecialty;
  CleaningStayPlan? _selectedPlan;
  String? _city;
  String _streetAddress = '';
  DateTime? _startsAt;
  String _instructions = '';
  CleaningBooking? _lastBooking;
  String? _submissionError;
  final Map<String, String> _validationErrors = {};

  List<CleaningProfessional> get professionals =>
      List.unmodifiable(_professionals);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isSubmitting => _isSubmitting;
  String? get loadError => _loadError;
  CleaningProfessional? get selectedProfessional => _selectedProfessional;
  CleaningSpecialty? get selectedSpecialty => _selectedSpecialty;
  CleaningStayPlan? get selectedPlan => _selectedPlan;
  String? get city => _city;
  String get streetAddress => _streetAddress;
  DateTime? get startsAt => _startsAt;
  String get instructions => _instructions;
  CleaningBooking? get lastBooking => _lastBooking;
  String? get submissionError => _submissionError;
  Map<String, String> get validationErrors =>
      Map.unmodifiable(_validationErrors);

  double get estimatedTotal => _selectedPlan?.total ?? 0;

  Future<void> load() async {
    final catalogRepository = _catalogRepository;
    if (catalogRepository == null || _isLoading) {
      return;
    }

    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final professionals = await catalogRepository.fetchProfessionals();
      _professionals
        ..clear()
        ..addAll(professionals);
      _hasLoaded = true;
    } on Object {
      _loadError = 'Cleaner profiles could not be loaded. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startNewBooking([CleaningProfessional? professional]) {
    _selectedProfessional = professional;
    _selectedSpecialty = null;
    _selectedPlan = null;
    _city = null;
    _streetAddress = '';
    _startsAt = null;
    _instructions = '';
    _lastBooking = null;
    _submissionError = null;
    _validationErrors.clear();
    notifyListeners();
  }

  void resetSessionState() {
    _repository.resetSessionState();
    startNewBooking();
  }

  void selectProfessional(CleaningProfessional? professional) {
    _selectedProfessional = professional;
    _selectedSpecialty = null;
    _selectedPlan = null;
    _clearError('professional');
    _clearError('specialty');
    _clearError('plan');
    notifyListeners();
  }

  void selectSpecialty(CleaningSpecialty? specialty) {
    _selectedSpecialty = specialty;
    _clearError('specialty');
    notifyListeners();
  }

  void selectPlan(CleaningStayPlan? plan) {
    _selectedPlan = plan;
    _clearError('plan');
    notifyListeners();
  }

  void selectCity(String? city) {
    _city = city;
    _clearError('city');
    notifyListeners();
  }

  void setStreetAddress(String address) {
    _streetAddress = address;
    _clearError('address');
    notifyListeners();
  }

  void setStartsAt(DateTime? startsAt) {
    _startsAt = startsAt;
    _clearError('startsAt');
    notifyListeners();
  }

  void setInstructions(String instructions) {
    _instructions = instructions;
    _clearError('instructions');
    notifyListeners();
  }

  bool validate() {
    _validationErrors.clear();
    final professional = _selectedProfessional;
    final specialty = _selectedSpecialty;
    final plan = _selectedPlan;

    if (professional == null) {
      _validationErrors['professional'] = 'Choose a cleaner.';
    }
    if (specialty == null) {
      _validationErrors['specialty'] = 'Choose one of their specialties.';
    } else if (professional == null ||
        !professional.offersSpecialty(specialty.id)) {
      _validationErrors['specialty'] =
          'Choose a specialty offered by this cleaner.';
    }
    if (plan == null) {
      _validationErrors['plan'] = 'Choose an arrangement length.';
    } else if (professional == null || !professional.offersPlan(plan)) {
      _validationErrors['plan'] = 'Choose a plan offered by this cleaner.';
    }
    if (_city == null || !supportedCities.contains(_city)) {
      _validationErrors['city'] = 'Choose a city in Somalia.';
    }
    if (_streetAddress.trim().length < 5) {
      _validationErrors['address'] =
          'Enter a complete street or neighbourhood address.';
    }
    final startsAt = _startsAt;
    if (startsAt == null) {
      _validationErrors['startsAt'] = 'Choose a start date and time.';
    } else if (!startsAt.isAfter(_now())) {
      _validationErrors['startsAt'] =
          'Choose a start date and time in the future.';
    }
    if (_instructions.trim().length > maxInstructionsLength) {
      _validationErrors['instructions'] =
          'Instructions must be $maxInstructionsLength characters or fewer.';
    }

    notifyListeners();
    return _validationErrors.isEmpty;
  }

  Future<CleaningBooking?> confirmBooking() async {
    if (_isSubmitting) {
      return null;
    }
    _submissionError = null;
    if (!validate()) {
      return null;
    }
    _isSubmitting = true;
    notifyListeners();

    final createdAt = _now();
    final request = CleaningBookingRequest(
      professional: _selectedProfessional!,
      specialty: _selectedSpecialty!,
      plan: _selectedPlan!,
      address: SomaliaAddress(
        streetAddress: _streetAddress.trim(),
        city: _city!,
      ),
      startsAt: _startsAt!,
      instructions: _instructions.trim(),
    );

    try {
      final receipt = await _bookingRepository?.placeBooking(request);
      final booking = receipt == null
          ? _repository.createBooking(
              id: _bookingIdFactory(),
              request: request,
              createdAt: createdAt,
            )
          : CleaningBooking(
              id: receipt.bookingId,
              request: request,
              cleaner: request.professional,
              status: CleaningBookingStatus.demoConfirmed,
              createdAt: receipt.createdAt,
            );
      _lastBooking = booking;
      _activityController.record(
        ActivityItem(
          id: booking.id,
          serviceId: ServiceId.cleaning,
          title: booking.request.specialty.name,
          subtitle:
              '${booking.cleaner.displayName} • '
              '${booking.request.plan.durationWeeks} weeks',
          status: booking.statusLabel,
          occurredAt: booking.createdAt,
          amount: booking.total,
          detailsRoute: '/cleaning',
        ),
      );
      notifyListeners();
      return booking;
    } on Object catch (error) {
      final message = error.toString().toLowerCase();
      _submissionError =
          error is NoCleanerAvailableException ||
              message.contains('selected cleaner is unavailable') ||
              message.contains('conflicting cleaning arrangement')
          ? 'This cleaner is unavailable for those dates. '
                'Please choose another start date.'
          : 'The cleaning arrangement could not be saved. Please try again.';
      notifyListeners();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _clearError(String field) {
    _validationErrors.remove(field);
    _submissionError = null;
  }
}
