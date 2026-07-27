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
    expect(ids, containsAll(ServiceId.values));
  });

  test('every service owns a distinct visual palette', () {
    final palettes = {
      for (final id in ServiceId.values) ServiceThemes.forId(id).accent,
    };

    expect(palettes, hasLength(ServiceId.values.length));
    expect(ServiceThemes.forId(ServiceId.grocery), ServiceThemes.grocery);
    expect(ServiceThemes.grocery.card, isNot(ServiceThemes.food.card));
  });
}
