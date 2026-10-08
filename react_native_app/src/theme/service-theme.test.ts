import { forId, forSlug, ServiceThemes } from './service-theme';

// Ports the palette cases implied by flutter_app/lib/config/
// service_theme.dart's `ServiceThemes.forId` / `forSlug` (issue #354).
describe('forId', () => {
  it('returns the food palette', () => {
    expect(forId('food')).toEqual(ServiceThemes.food);
  });

  it('returns the grocery palette', () => {
    expect(forId('grocery')).toEqual(ServiceThemes.grocery);
  });

  it('returns the pharmacy palette', () => {
    expect(forId('pharmacy')).toEqual(ServiceThemes.pharmacy);
  });

  it('falls back to the neutral platform palette for unknown', () => {
    expect(forId('unknown')).toEqual(ServiceThemes.platform);
  });
});

describe('forSlug', () => {
  it('returns the Fresh Meat palette regardless of the underlying id', () => {
    expect(forSlug('fresh-meat', 'grocery')).toEqual(ServiceThemes.freshMeat);
  });

  it('returns the Electronics palette regardless of the underlying id', () => {
    expect(forSlug('electronics', 'grocery')).toEqual(
      ServiceThemes.electronics,
    );
  });

  it('falls back to forId for a slug with no dedicated palette', () => {
    expect(forSlug('grocery', 'grocery')).toEqual(ServiceThemes.grocery);
    expect(forSlug('food', 'food')).toEqual(ServiceThemes.food);
  });
});

describe('ServiceThemes palettes', () => {
  it('matches the Flutter accent colors 1:1', () => {
    expect(ServiceThemes.food.accent).toBe('#C2410C');
    expect(ServiceThemes.grocery.accent).toBe('#15803D');
    expect(ServiceThemes.pharmacy.accent).toBe('#7C3AED');
    expect(ServiceThemes.freshMeat.accent).toBe('#B91C1C');
    expect(ServiceThemes.electronics.accent).toBe('#1D4ED8');
  });
});
