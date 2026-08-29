import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Minimal transparent 1x1 PNG, used to satisfy any `NetworkImage` load
/// during widget tests without making a real HTTP request.
final Uint8List kTestTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

/// Runs [body] with `HttpOverrides` swapped for a stub that answers every
/// request with [kTestTransparentImage]. Widgets that render a real
/// `NetworkImage`/`Image.network` (e.g. the onboarding hero photos, which
/// unlike the catalog cards' `CachedNetworkImage` have no empty-URL
/// fallback) otherwise trigger an unhandled `NetworkImageLoadException` in
/// `flutter test`'s no-network sandbox and fail the test even when every
/// assertion in it passes.
Future<void> withMockNetworkImages(Future<void> Function() body) {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (context) => _FakeHttpClient(),
  );
}

/// Base for the fake `dart:io` HTTP classes below: forwards every member
/// this test doesn't care about to `noSuchMethod` instead of requiring a
/// full implementation of each interface.
class _Fake {
  // Swallow anything not explicitly overridden below (setters like
  // `autoUncompress=`, unrelated getters, etc.) instead of throwing, since
  // only a handful of `HttpClient`/`HttpClientRequest`/... members are
  // actually exercised by an `Image.network`/`NetworkImage` load.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClient extends _Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();
}

class _FakeHttpClientRequest extends _Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
}

class _FakeHttpHeaders extends _Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpClientResponse extends _Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => kTestTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[
      kTestTransparentImage,
    ]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
