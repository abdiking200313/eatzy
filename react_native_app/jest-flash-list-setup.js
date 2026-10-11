// FlashList v2 test setup (issue #417 -- P10-05).
//
// FlashList measures its viewport and every row natively; Jest has no
// layout pass, so unmeasured it renders no rows at all. This gives it a
// fixed phone-sized viewport (400x900) and 100pt rows, so the real
// component renders its first screenful (plus draw distance) exactly as it
// would on a device.
//
// `@shopify/flash-list/jestSetup` ships the same idea, but 2.0.2's copy
// also replaces `FlashList` with a `RecyclerView` export that no longer
// exists (it resolves to `undefined`), so only its measurement half is
// reproduced here. A test can still `jest.mock('@shopify/flash-list', ...)`
// its own stand-in (see the restaurant menu screen's test), which wins.
jest.mock('@shopify/flash-list/dist/recyclerview/utils/measureLayout', () => {
  const actual = jest.requireActual('@shopify/flash-list/dist/recyclerview/utils/measureLayout');
  return {
    ...actual,
    measureParentSize: jest.fn(() => ({ x: 0, y: 0, width: 400, height: 900 })),
    measureFirstChildLayout: jest.fn(() => ({ x: 0, y: 0, width: 400, height: 900 })),
    measureItemLayout: jest.fn(() => ({ x: 0, y: 0, width: 100, height: 100 })),
  };
});
