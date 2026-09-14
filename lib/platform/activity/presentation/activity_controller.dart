import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/activity_repository.dart';
import '../models/activity_item.dart';

/// Unified activity feed for the food/grocery/pharmacy verticals.
///
/// This is a hand-rolled `ChangeNotifier` singleton (see [instance]) rather
/// than a `@riverpod`/`AsyncNotifier`, which is otherwise this project's
/// stated state-management convention. That is a deliberate, accepted
/// exception -- not an oversight -- per the resolution of issue #19: a full
/// Riverpod migration was judged a bigger refactor than the issue's scope
/// warranted, and AGENTS.md itself says not to introduce a new state
/// management framework for a localized task without an explicit
/// architectural reason and user agreement. Revisit only with a fresh,
/// explicit decision to migrate, not as an incidental side effect of an
/// unrelated change.
class ActivityController extends ChangeNotifier {
  ActivityController({ActivityRepository? repository})
    : _repository = repository;

  static final ActivityController instance = ActivityController();

  ActivityRepository? _repository;
  final List<ActivityItem> _items = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _loadError;

  UnmodifiableListView<ActivityItem> get items => UnmodifiableListView(_items);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get loadError => _loadError;

  void configureRepository(ActivityRepository repository) {
    _repository = repository;
  }

  Future<void> load() async {
    final repository = _repository;
    if (repository == null || _isLoading) {
      return;
    }

    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final items = await repository.fetchActivities();
      _items
        ..clear()
        ..addAll(items);
      _hasLoaded = true;
    } on Object catch (error, stackTrace) {
      _loadError = 'Activity could not be loaded. Please try again.';
      debugPrint('ActivityController.load failed: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void record(ActivityItem item) {
    _items
      ..removeWhere((existing) => existing.id == item.id)
      ..add(item)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    notifyListeners();
  }

  void resetSessionState() {
    _items.clear();
    _hasLoaded = false;
    _loadError = null;
    notifyListeners();
  }

  @visibleForTesting
  void clear() => resetSessionState();
}
