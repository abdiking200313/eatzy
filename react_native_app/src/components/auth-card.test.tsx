import { Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';
import { rawColors } from '@/theme/tokens';

import { AuthCard } from './auth-card';

describe('AuthCard', () => {
  it('renders its children', async () => {
    const { getByText } = await renderWithProviders(
      <AuthCard>
        <Text>Sign in form</Text>
      </AuthCard>,
    );

    expect(getByText('Sign in form')).toBeOnTheScreen();
  });

  it('always uses the fixed white background, independent of color scheme', async () => {
    const { getByText } = await renderWithProviders(
      <AuthCard>
        <Text>Sign in form</Text>
      </AuthCard>,
    );

    const card = getByText('Sign in form').parent!;
    expect(card).toHaveStyle({ backgroundColor: rawColors.white });
  });
});
