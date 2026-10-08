// NativeWind v4 setup (issue #352). See https://www.nativewind.dev/getting-started/installation.
module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      ['babel-preset-expo', { jsxImportSource: 'nativewind' }],
      'nativewind/babel',
    ],
  };
};
