// Stub for a plain `.css` import under Jest (e.g. `src/global.css`, imported
// by `src/constants/theme.ts`). Metro's web bundler understands importing
// CSS directly and no-ops it on native platforms; Jest has no bundler step
// at all, so without this mapping (see jest.config.js's
// `moduleNameMapper`) a `.css` file's raw contents reach Jest's JS parser
// and fail with a syntax error. Real styling behavior from this file is
// never under test — it only declares CSS custom properties for font
// stacks on web — so an empty module is a faithful enough stand-in.
module.exports = {};
