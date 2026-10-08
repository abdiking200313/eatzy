import { renderHook } from '@testing-library/react-native';

import { ServiceThemes } from '@/theme/service-theme';

import { useServiceTheme } from './use-service-theme';

describe('useServiceTheme', () => {
  it('returns the palette for a plain service id', async () => {
    const { result } = await renderHook(() => useServiceTheme('food'));

    expect(result.current).toEqual(ServiceThemes.food);
  });

  it('returns the grocery palette when no slug overrides it', async () => {
    const { result } = await renderHook(() => useServiceTheme('grocery'));

    expect(result.current).toEqual(ServiceThemes.grocery);
  });

  it("returns the Fresh Meat palette for grocery's fresh-meat slug", async () => {
    const { result } = await renderHook(() =>
      useServiceTheme('grocery', 'fresh-meat'),
    );

    expect(result.current).toEqual(ServiceThemes.freshMeat);
  });

  it("returns the Electronics palette for grocery's electronics slug", async () => {
    const { result } = await renderHook(() =>
      useServiceTheme('grocery', 'electronics'),
    );

    expect(result.current).toEqual(ServiceThemes.electronics);
  });

  it('falls back to the neutral platform palette for unknown', async () => {
    const { result } = await renderHook(() => useServiceTheme('unknown'));

    expect(result.current).toEqual(ServiceThemes.platform);
  });

  it('memoizes the result across re-renders with the same inputs', async () => {
    const { result, rerender } = await renderHook(
      ({ service }: { service: 'food' }) => useServiceTheme(service),
      { initialProps: { service: 'food' } },
    );
    const first = result.current;

    await rerender({ service: 'food' });

    expect(result.current).toBe(first);
  });
});
