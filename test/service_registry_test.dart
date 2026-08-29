import 'package:chowflow/app/service_module.dart';
import 'package:chowflow/config/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service registry exposes unique IDs and entry routes', () {
    final ids = ServiceRegistry.modules.map((module) => module.id).toSet();
    final routes = ServiceRegistry.modules
        .map((module) => module.entryRoute)
        .toSet();

    expect(ids.length, ServiceRegistry.modules.length);
    expect(routes.length, ServiceRegistry.modules.length);
    // ServiceId.unknown is a fallback for legacy/malformed activity rows
    // (#62), not a purchasable module, so it is intentionally absent from
    // ServiceRegistry.modules.
    expect(
      ids,
      containsAll(ServiceId.values.toSet()..remove(ServiceId.unknown)),
    );
    expect(ids, isNot(contains(ServiceId.unknown)));
  });

  test('every service owns a distinct visual palette', () {
    final palettes = {
      for (final id in ServiceId.values) ServiceThemes.forId(id).accent,
    };

    expect(palettes, hasLength(ServiceId.values.length));
    expect(ServiceThemes.forId(ServiceId.grocery), ServiceThemes.grocery);
    expect(ServiceThemes.grocery.card, isNot(ServiceThemes.food.card));
  });

  test(
    'an id with no registered module falls back to a generic descriptor',
    () {
      final descriptor = ServiceRegistry.byId(ServiceId.unknown);

      expect(descriptor.id, ServiceId.unknown);
      expect(descriptor, ServiceRegistry.unknownModule);
    },
  );
}
