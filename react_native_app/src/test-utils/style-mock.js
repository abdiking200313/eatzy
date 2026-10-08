// Stub for `.css`/`.scss` imports under Jest (issue #349).
//
// `src/constants/theme.ts` does `import '@/global.css'` for the web build
// (Metro/webpack's CSS loader handles it there); Jest has no CSS loader and
// doesn't need one; see this file's use in `package.json`'s
// `jest.moduleNameMapper`.
module.exports = {};
