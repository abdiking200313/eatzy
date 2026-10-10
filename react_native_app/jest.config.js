// Jest configuration (issue #349 — P0-07).
//
// Uses the `jest-expo` preset (not `jest-expo/universal`): this app ships a
// single React Native + web client from one source tree, and the default
// preset already runs tests under a React Native-shaped environment with
// Expo's native modules mocked — the heavier `/universal` preset's extra
// per-platform projects (separate ios/android/web/node runs) aren't needed
// for this app's test suite yet. Revisit if/when web-specific test behavior
// actually diverges from native.
/** @type {import('jest').Config} */
module.exports = {
  preset: 'jest-expo',
  // Mirrors tsconfig.json's "@/*" / "@/assets/*" path aliases (Metro resolves
  // these natively at bundle time; Jest does not read tsconfig "paths" on its
  // own, so it needs this explicit mapping to resolve the same imports).
  // Order matters: more specific patterns must come before the broader
  // "@/*" alias below, or they'd never be reached (e.g. "@/global.css"
  // matches both the alias and the ".css$" rule — the first match wins).
  moduleNameMapper: {
    '\\.css$': '<rootDir>/jest-style-mock.js',
    '^@/assets/(.*)$': '<rootDir>/assets/$1',
    '^@/(.*)$': '<rootDir>/src/$1',
    // `@react-native-async-storage/async-storage`'s real native module
    // throws immediately on import under Jest ("NativeModule: AsyncStorage
    // is null") rather than lazily when called — the package's own docs
    // call for exactly this mapping (issue #360, which first needed
    // AsyncStorage outside of code that already had a fully-mocked
    // ancestor module, e.g. `onboarding-preferences.ts`/`onboarding-
    // store.ts`, reached transitively by the root `_layout.tsx`).
    '^@react-native-async-storage/async-storage$':
      '<rootDir>/node_modules/@react-native-async-storage/async-storage/jest/async-storage-mock',
  },
  // Stubs FlashList's native layout measurement so list rows render under
  // Jest (issue #383) -- see that file's comment for why it replaces
  // `@shopify/flash-list/jestSetup.js`. Jest appends this to the
  // `jest-expo` preset's own `setupFiles` rather than replacing them.
  setupFiles: ['<rootDir>/jest-flash-list-setup.js'],
  // Keep the default transformIgnorePatterns from `jest-expo` (it already
  // allows transforming Expo/React Navigation/React Native's own ESM-only
  // packages); add to this list here if a newly added dependency ships
  // untranspiled ESM and shows up as a "Cannot use import statement outside
  // a module" failure.
};
