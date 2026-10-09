/**
 * Covers the part of issue #361's acceptance criteria
 * ("Opening `zivo://track-order/123` opens that route") this sandbox can
 * verify without a real device opening a `zivo://` link.
 *
 * Two things have to be true for a `zivo://track-order/:serviceId/:orderId`
 * deep link to open `src/app/(app)/track-order/[serviceId]/[orderId].tsx`:
 *
 *  1. `app.json`'s `expo.scheme` must be `zivo` (it registers the native
 *     intent filter / URL scheme `Linking` listens for) -- checked directly
 *     below, since that's the one-line config fix this issue needed and the
 *     part a routing test alone wouldn't catch.
 *  2. Expo Router's own native deep-link handling must resolve the
 *     `zivo://...` URL down to the in-app path `/track-order/:serviceId/
 *     :orderId`. That happens inside `node_modules/expo-router/build/fork/
 *     extractPathFromURL.js`'s `fromDeepLink`, which (for a custom,
 *     non-`http(s)` scheme) parses the URL and concatenates `host +
 *     pathname` -- i.e. for `zivo://track-order/food/order-1`,
 *     `new URL(...)` parses `host` as `"track-order"` and `pathname` as
 *     `"/food/order-1"`, giving the in-app path `"track-order/food/
 *     order-1"`. This is Expo Router's own, already-exercised machinery
 *     (every other deep link in this app -- `/food`, `/settings`, etc. --
 *     already relies on the same mechanism), not new code added by this
 *     issue, so rather than re-testing Expo Router itself, this documents
 *     the exact `host`/`pathname` split the real native handler relies on
 *     for this route's shape, using the same `URL` global it uses
 *     internally. `src/route-reachability.test.tsx` (#358) separately
 *     confirms the *result* of that split --
 *     `/track-order/:serviceId/:orderId` -- actually resolves to a real
 *     screen via `expo-router/testing-library`'s `renderRouter`.
 *
 * `/track-order/123` (the issue text's literal, single-segment example)
 * does not match any registered route in either this app or
 * `flutter_app`'s `app_routes.dart` -- the real, navigable form has always
 * required both a `serviceId` and an `orderId` (see `trackOrderDetailsPath`
 * in `app-routes.ts` and its Flutter counterpart); the bare `/track-order`
 * path (no further segments) is the one kept for an old link with no order
 * to point at. This file verifies the real two-segment form instead.
 */
import appJson from '../../../app.json';

import { isTrackOrderDetails, trackOrderDetailsPath } from './app-routes';

describe('zivo:// deep link scheme (issue #361)', () => {
  it('registers the zivo scheme in app.json, matching flutter_app\'s AndroidManifest/Info.plist', () => {
    expect(appJson.expo.scheme).toBe('zivo');
  });

  it('splits a track-order deep link into the host/pathname Expo Router concatenates into the in-app path', () => {
    const deepLink = `zivo://${trackOrderDetailsPath({ serviceId: 'food', orderId: 'order-1' }).slice(1)}`;
    const parsed = new URL(deepLink);

    expect(parsed.host).toBe('track-order');
    expect(parsed.pathname).toBe('/food/order-1');
    expect(`${parsed.host}${parsed.pathname}`).toBe(trackOrderDetailsPath({ serviceId: 'food', orderId: 'order-1' }).slice(1));
    expect(isTrackOrderDetails(trackOrderDetailsPath({ serviceId: 'food', orderId: 'order-1' }))).toBe(true);
  });
});
