import '../../services/grocery/presentation/grocery_controller.dart';
import '../../services/pharmacy/presentation/pharmacy_controller.dart';
import '../activity/presentation/activity_controller.dart';

/// Clears account-scoped in-memory MVP state when the authenticated owner
/// changes. Seeded catalogs remain loaded because they contain no user data.
class AccountStateCoordinator {
  AccountStateCoordinator({
    required String? initialOwnerId,
    ActivityController? activityController,
    GroceryController? groceryController,
    PharmacyController? pharmacyController,
  }) : _ownerId = initialOwnerId,
       _activityController = activityController ?? ActivityController.instance,
       _groceryController = groceryController ?? GroceryController.instance,
       _pharmacyController = pharmacyController ?? PharmacyController.instance;

  String? _ownerId;
  final ActivityController _activityController;
  final GroceryController _groceryController;
  final PharmacyController _pharmacyController;

  String? get ownerId => _ownerId;

  bool handleOwnerChanged(String? nextOwnerId) {
    if (_ownerId == nextOwnerId) {
      return false;
    }

    _ownerId = nextOwnerId;
    _activityController.resetSessionState();
    _groceryController.resetSessionState();
    _pharmacyController.resetSessionState();
    return true;
  }
}
