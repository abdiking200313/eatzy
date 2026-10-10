/**
 * Ports the `ServiceRegistry`-specific cases from
 * `flutter_app/test/service_registry_test.dart` (issue #371 / P4-05).
 *
 * Not ported here:
 * - "every service owns a distinct visual palette" -- that's
 *   `ServiceThemes`/`forId`, already covered end-to-end by
 *   `src/theme/service-theme.test.ts` (issue #354 / P1-03).
 * - `flutter_app/test/app_services_test.dart` -- despite being named in
 *   #371's "Flutter tests to port or match", none of its cases are about
 *   the service list; they cover `AppServices.groceryController`/
 *   `pharmacyController` lazy-build-and-cache behavior, an unrelated
 *   composition-root concern for a later phase.
 */
import { ServiceRegistry } from './registry';

describe('ServiceRegistry.modules', () => {
  it('exposes unique slugs and entry routes', () => {
    const slugs = new Set(ServiceRegistry.modules.map((module) => module.slug));
    const routes = new Set(ServiceRegistry.modules.map((module) => module.entryRoute));

    // Fresh Meat and Electronics share the 'grocery' id (grocery-engine
    // store lists), so tiles are told apart by slug, not id.
    expect(slugs.size).toBe(ServiceRegistry.modules.length);
    expect(routes.size).toBe(ServiceRegistry.modules.length);
  });

  it('covers every purchasable ServiceId and excludes "unknown"', () => {
    const ids = new Set(ServiceRegistry.modules.map((module) => module.id));

    // `unknown` is a fallback for legacy/malformed activity rows, not a
    // purchasable module, so it is intentionally absent from `modules`.
    expect(ids).toEqual(new Set(['food', 'grocery', 'pharmacy']));
  });
});

describe('ServiceRegistry.comingSoon', () => {
  it('lists placeholders outside the module list', () => {
    const ids = new Set(ServiceRegistry.comingSoon.map((category) => category.id));
    const moduleTitles = new Set(ServiceRegistry.modules.map((module) => module.title));
    const comingSoonTitles = new Set(ServiceRegistry.comingSoon.map((category) => category.title));

    expect(ids.size).toBe(ServiceRegistry.comingSoon.length);
    for (const title of comingSoonTitles) {
      expect(moduleTitles.has(title)).toBe(false);
    }
  });
});

describe('ServiceRegistry.byId', () => {
  it('falls back to the generic descriptor for an id with no registered module', () => {
    const descriptor = ServiceRegistry.byId('unknown');

    expect(descriptor.id).toBe('unknown');
    expect(descriptor).toEqual(ServiceRegistry.unknownModule);
  });

  it('returns the first registered module for a real id', () => {
    expect(ServiceRegistry.byId('food').title).toBe('Food');
    expect(ServiceRegistry.byId('pharmacy').title).toBe('Pharmacy');
    // Three modules share the 'grocery' id; byId returns the first
    // (the plain "Grocery" tile), mirroring Dart's `firstWhere`.
    expect(ServiceRegistry.byId('grocery').title).toBe('Grocery');
  });
});
