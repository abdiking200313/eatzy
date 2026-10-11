/* global output, E2E_PASSWORD, E2E_EMAIL_DOMAIN, E2E_FIRST_NAME, E2E_LAST_NAME, E2E_PHONE, E2E_RESTAURANT_NAME, E2E_MENU_ITEM_NAME */
// Maestro `runScript` helper for customer-food-order.yaml.
//
// Reads the flow's `-e` environment variables (Maestro exposes
// each one as a global), fails fast with a readable message when a required
// one is missing, and publishes the derived values on `output.customer` for
// the flow to reference as `${output.customer.*}`.
//
// Nothing secret or environment-specific is hardcoded here: the throwaway
// customer's password and the seeded restaurant/menu item all come from the
// caller. See README.md ("End-to-end tests").

// Each variable is read with its own `typeof X === 'undefined'` guard (an
// unset one is an undeclared global, so a bare reference would throw a
// ReferenceError) and passed in here alongside its name for the message.
function readVar(name, value, fallback) {
  if (value === undefined || value === null || String(value).trim() === '') {
    if (fallback === undefined) {
      throw new Error('Missing required Maestro env var ' + name + ' (pass it with -e ' + name + '=...)');
    }
    return fallback;
  }
  return String(value);
}

var password = readVar('E2E_PASSWORD', typeof E2E_PASSWORD === 'undefined' ? undefined : E2E_PASSWORD);
if (password.length < 6) {
  throw new Error('E2E_PASSWORD must be at least 6 characters (register.tsx rejects shorter passwords).');
}

var emailDomain = readVar(
  'E2E_EMAIL_DOMAIN',
  typeof E2E_EMAIL_DOMAIN === 'undefined' ? undefined : E2E_EMAIL_DOMAIN,
  'example.com',
);

output.customer = {
  // A fresh address on every run, so sign-up never collides with an
  // earlier run's account on the dev project.
  email: 'e2e+' + Date.now() + '@' + emailDomain,
  password: password,
  firstName: readVar('E2E_FIRST_NAME', typeof E2E_FIRST_NAME === 'undefined' ? undefined : E2E_FIRST_NAME, 'Maestro'),
  lastName: readVar('E2E_LAST_NAME', typeof E2E_LAST_NAME === 'undefined' ? undefined : E2E_LAST_NAME, 'Tester'),
  phone: readVar('E2E_PHONE', typeof E2E_PHONE === 'undefined' ? undefined : E2E_PHONE, '+15551234567'),
  restaurantName: readVar(
    'E2E_RESTAURANT_NAME',
    typeof E2E_RESTAURANT_NAME === 'undefined' ? undefined : E2E_RESTAURANT_NAME,
  ),
  menuItemName: readVar(
    'E2E_MENU_ITEM_NAME',
    typeof E2E_MENU_ITEM_NAME === 'undefined' ? undefined : E2E_MENU_ITEM_NAME,
  ),
};
