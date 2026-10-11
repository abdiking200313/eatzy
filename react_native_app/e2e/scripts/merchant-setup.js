/* global output, E2E_MERCHANT_EMAIL, E2E_MERCHANT_PASSWORD, E2E_ORDER_ID */
// Maestro `runScript` helper for merchant-order.yaml.
//
// Reads the flow's `-e` environment variables (Maestro exposes each one as
// a global), fails fast with a readable message when a required one is
// missing, and publishes the values on `output.merchant` for the flow to
// reference as `${output.merchant.*}`.
//
// Nothing secret or environment-specific is hardcoded here: the merchant
// account and (optionally) the order to work on come from the caller. See
// README.md ("Merchant order flow").

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

var orderId = readVar('E2E_ORDER_ID', typeof E2E_ORDER_ID === 'undefined' ? undefined : E2E_ORDER_ID, '').trim();
if (orderId !== '' && !/^[0-9a-fA-F-]{36}$/.test(orderId)) {
  throw new Error('E2E_ORDER_ID must be the full order uuid (the merchant Orders list only shows its first 8 characters).');
}

output.merchant = {
  email: readVar('E2E_MERCHANT_EMAIL', typeof E2E_MERCHANT_EMAIL === 'undefined' ? undefined : E2E_MERCHANT_EMAIL),
  password: readVar(
    'E2E_MERCHANT_PASSWORD',
    typeof E2E_MERCHANT_PASSWORD === 'undefined' ? undefined : E2E_MERCHANT_PASSWORD,
  ),
  // '' means "open the first Confirmed order in the list" (see the flow).
  orderId: orderId.toLowerCase(),
};
