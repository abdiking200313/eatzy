import { renderWithProviders } from '@/test-utils';

import { CartSnackbar } from './cart-snackbar';

describe('CartSnackbar', () => {
  it('renders nothing when message is null', async () => {
    const { toJSON } = await renderWithProviders(<CartSnackbar message={null} />);

    expect(toJSON()).toBeNull();
  });

  it('renders the message when given one', async () => {
    const { getByText } = await renderWithProviders(<CartSnackbar message="Added to cart" />);

    expect(getByText('Added to cart')).toBeOnTheScreen();
  });

  it('does not intercept touches (pointerEvents="none")', async () => {
    const { getByText } = await renderWithProviders(<CartSnackbar message="Added to cart" />);

    // Walk up to the outer, absolutely-positioned wrapper, which is what
    // carries `pointerEvents="none"` so the snackbar never blocks taps on
    // whatever is underneath it.
    const outer = getByText('Added to cart').parent!.parent!;
    expect(outer.props.pointerEvents).toBe('none');
  });
});
