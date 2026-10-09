import { Dimensions, Text } from 'react-native';

import { renderWithProviders } from '@/test-utils';

import { AuthPageBackground } from './auth-page-background';

describe('AuthPageBackground', () => {
  it('renders its children', async () => {
    const { getByText } = await renderWithProviders(
      <AuthPageBackground>
        <Text>Login form</Text>
      </AuthPageBackground>,
    );

    expect(getByText('Login form')).toBeOnTheScreen();
  });

  it('is at least as tall as the window, so a short form still fills it', async () => {
    const { getByText } = await renderWithProviders(
      <AuthPageBackground>
        <Text>Login form</Text>
      </AuthPageBackground>,
    );

    const windowHeight = Dimensions.get('window').height;
    const wrapper = getByText('Login form').parent!;
    expect(wrapper).toHaveStyle({ minHeight: windowHeight });
  });
});
