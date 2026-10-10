// FlashList Jest setup (issue #383). Mirrors the measurement stubs from
// `@shopify/flash-list/jestSetup.js` -- a fixed 400x900 viewport and
// 100x100 rows, since Jest has no native layout -- so list rows actually
// render under test. That file itself is not used directly: in 2.0.2 its
// other mock remaps `FlashList` to a `RecyclerView` export the package's
// index no longer has, leaving `FlashList` undefined.
jest.mock('@shopify/flash-list/dist/recyclerview/utils/measureLayout', () => {
  const originalModule = jest.requireActual('@shopify/flash-list/dist/recyclerview/utils/measureLayout');
  return {
    ...originalModule,
    measureParentSize: jest.fn().mockImplementation(() => ({ x: 0, y: 0, width: 400, height: 900 })),
    measureFirstChildLayout: jest.fn().mockImplementation(() => ({ x: 0, y: 0, width: 400, height: 900 })),
    measureItemLayout: jest.fn().mockImplementation(() => ({ x: 0, y: 0, width: 100, height: 100 })),
  };
});
