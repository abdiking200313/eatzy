/**
 * Issue #545. Flutter has no dedicated AddressesScreen test (its only
 * coverage is route_reachability_test.dart mounting the route), so this
 * checks the rendered content against the Flutter screen's hardcoded list.
 */
import { renderWithProviders } from '@/test-utils';

import { AddressesScreen, DEMO_ADDRESSES } from './addresses-screen';

describe('AddressesScreen', () => {
  it('renders the Saved Addresses title, a back button and the Add New Address button', async () => {
    const { getByText, getByLabelText } = await renderWithProviders(<AddressesScreen />);

    expect(getByText('Saved Addresses')).toBeOnTheScreen();
    expect(getByLabelText('Back')).toBeOnTheScreen();
    expect(getByLabelText('Add New Address')).toBeOnTheScreen();
  });

  it('renders every demo address with its edit and delete actions, dividers between rows', async () => {
    const { getByText, getByLabelText, getAllByTestId } = await renderWithProviders(<AddressesScreen />);

    for (const address of DEMO_ADDRESSES) {
      expect(getByText(address.label)).toBeOnTheScreen();
      expect(getByText(address.address)).toBeOnTheScreen();
      expect(getByLabelText(`Edit ${address.label}`)).toBeOnTheScreen();
      expect(getByLabelText(`Delete ${address.label}`)).toBeOnTheScreen();
    }
    expect(getAllByTestId('addresses-list-divider')).toHaveLength(DEMO_ADDRESSES.length - 1);
  });

  it('marks only the default address, whose button is disabled', async () => {
    const { getAllByText, getByLabelText, getAllByLabelText } = await renderWithProviders(<AddressesScreen />);

    expect(getAllByText('Default')).toHaveLength(1);
    expect(getByLabelText('Default Address')).toBeDisabled();
    const setAsDefault = getAllByLabelText('Set as Default');
    expect(setAsDefault).toHaveLength(DEMO_ADDRESSES.filter((address) => !address.isDefault).length);
    for (const button of setAsDefault) expect(button).toBeEnabled();
  });
});
