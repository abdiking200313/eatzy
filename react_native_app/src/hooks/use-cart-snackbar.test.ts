import { act, renderHook } from '@testing-library/react-native';

import { useCartSnackbar } from './use-cart-snackbar';

describe('useCartSnackbar', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('starts with no message', async () => {
    const { result } = await renderHook(() => useCartSnackbar());

    expect(result.current.message).toBeNull();
  });

  it('shows a message when show() is called', async () => {
    const { result } = await renderHook(() => useCartSnackbar());

    await act(() => {
      result.current.show('Added to cart');
    });

    expect(result.current.message).toBe('Added to cart');
  });

  it('auto-hides the message after 1800ms', async () => {
    const { result } = await renderHook(() => useCartSnackbar());

    await act(() => {
      result.current.show('Added to cart');
    });
    await act(() => {
      jest.advanceTimersByTime(1800);
    });

    expect(result.current.message).toBeNull();
  });

  it('replaces (does not queue behind) a message already showing', async () => {
    const { result } = await renderHook(() => useCartSnackbar());

    await act(() => {
      result.current.show('Added to cart');
    });
    await act(() => {
      jest.advanceTimersByTime(1000);
    });
    await act(() => {
      result.current.show('Quantity increased');
    });

    // The first message's timer was cleared, not left running behind the
    // new one: advancing only 800ms more (1800ms total since the first
    // show(), but only 800ms since the second) must not hide the new
    // message yet.
    await act(() => {
      jest.advanceTimersByTime(800);
    });
    expect(result.current.message).toBe('Quantity increased');

    await act(() => {
      jest.advanceTimersByTime(1000);
    });
    expect(result.current.message).toBeNull();
  });
});
