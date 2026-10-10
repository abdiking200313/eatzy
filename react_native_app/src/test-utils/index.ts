/// Barrel for this app's shared test helpers (issue #349). Import from
/// `@/test-utils` rather than reaching into individual files, so helpers can
/// be reorganized later without touching every test that uses them.
export * from './fake-supabase-client';
export * from './memory-cart-storage';
export * from './render-with-providers';
