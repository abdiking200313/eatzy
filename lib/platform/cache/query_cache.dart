import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where [QueryCache] persists entries between app launches.
abstract class QueryCacheStorage {
  /// Every persisted entry, keyed by cache key, as the JSON strings passed
  /// to [write].
  Future<Map<String, String>> readAll();

  Future<void> write(String key, String json);

  Future<void> remove(String key);
}

/// A [QueryCacheStorage] backed by [SharedPreferencesAsync], mirroring
/// `SharedPreferencesCartStorage`. Keys are namespaced under [_prefix] so
/// [readAll] never picks up unrelated preferences.
class SharedPreferencesQueryCacheStorage implements QueryCacheStorage {
  const SharedPreferencesQueryCacheStorage();

  static const _prefix = 'query_cache:';

  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();

  @override
  Future<Map<String, String>> readAll() async {
    final keys = (await _preferences.getKeys())
        .where((key) => key.startsWith(_prefix))
        .toSet();
    if (keys.isEmpty) return const {};
    final values = await _preferences.getAll(allowList: keys);
    return {
      for (final entry in values.entries)
        if (entry.value is String)
          entry.key.substring(_prefix.length): entry.value as String,
    };
  }

  @override
  Future<void> write(String key, String json) =>
      _preferences.setString('$_prefix$key', json);

  @override
  Future<void> remove(String key) => _preferences.remove('$_prefix$key');
}

class _CacheEntry {
  const _CacheEntry(this.value, this.savedAt);

  /// JSON-encodable (maps/lists/primitives only), so it can be written to
  /// disk as-is and decoded identically whether it came from memory or disk.
  final Object? value;
  final DateTime savedAt;
}

/// Stale-while-revalidate cache for read-only catalog data (restaurants,
/// menus, store listings): screens render the last known value immediately
/// and refresh it in the background, instead of showing a spinner on every
/// visit.
///
/// Entries live in memory and are mirrored to [QueryCacheStorage] so a cold
/// start can also render instantly once [hydrate] has run. Only put public,
/// non-user-specific data here — nothing is cleared on sign-out.
///
/// Use it through [CachedQuery], which adds typed encode/decode on top.
class QueryCache {
  QueryCache({QueryCacheStorage? storage, DateTime Function()? clock})
    : _storage = storage ?? const SharedPreferencesQueryCacheStorage(),
      _clock = clock ?? DateTime.now;

  static final QueryCache instance = QueryCache();

  /// Upper bound on cached entries (memory and disk alike); the oldest are
  /// evicted first. Keeps per-restaurant menu entries from growing forever.
  static const int maxEntries = 50;

  /// Disk entries older than this are dropped on [hydrate] rather than shown.
  static const Duration maxDiskAge = Duration(days: 7);

  final QueryCacheStorage _storage;
  final DateTime Function() _clock;
  final _entries = <String, _CacheEntry>{};
  final _inflight = <String, Future<Object?>>{};

  /// Loads persisted entries into memory. Call once at startup, before the
  /// first screen reads the cache; entries already in memory win.
  Future<void> hydrate() async {
    final now = _clock();
    final stored = await _storage.readAll();
    for (final MapEntry(:key, value: json) in stored.entries) {
      try {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final savedAt = DateTime.fromMillisecondsSinceEpoch(
          decoded['t'] as int,
        );
        if (now.difference(savedAt) > maxDiskAge) {
          unawaited(_storage.remove(key));
          continue;
        }
        _entries.putIfAbsent(key, () => _CacheEntry(decoded['v'], savedAt));
      } on Object {
        unawaited(_storage.remove(key));
      }
    }
  }

  /// The cached JSON value for [key], or null when nothing is cached.
  Object? peek(String key) => _entries[key]?.value;

  bool contains(String key) => _entries.containsKey(key);

  /// Whether [key] was saved less than [maxAge] ago.
  bool isFresh(String key, Duration maxAge) {
    final entry = _entries[key];
    return entry != null && _clock().difference(entry.savedAt) < maxAge;
  }

  /// Runs [load] and stores its JSON-encodable result under [key].
  /// Concurrent calls for the same key share one in-flight request, so a
  /// prefetch and the screen that needs the data never both hit the network.
  Future<Object?> fetch(String key, Future<Object?> Function() load) {
    return _inflight[key] ??= () async {
      try {
        final value = await load();
        _put(key, _CacheEntry(value, _clock()));
        return value;
      } finally {
        _inflight.remove(key);
      }
    }();
  }

  void _put(String key, _CacheEntry entry) {
    _entries.remove(key);
    _entries[key] = entry;
    unawaited(_persist(key, entry));
    while (_entries.length > maxEntries) {
      // Map iteration order is insertion order and [_put] re-inserts on
      // every write, so the first key is always the least recently saved.
      final oldest = _entries.keys.first;
      _entries.remove(oldest);
      unawaited(_ignoreErrors(() => _storage.remove(oldest)));
    }
  }

  Future<void> _persist(String key, _CacheEntry entry) => _ignoreErrors(
    () => _storage.write(
      key,
      jsonEncode({'t': entry.savedAt.millisecondsSinceEpoch, 'v': entry.value}),
    ),
  );

  /// Disk is only an optimization for the next cold start: a failed write
  /// must never break the in-memory result the screen is waiting on.
  static Future<void> _ignoreErrors(Future<void> Function() body) async {
    try {
      await body();
    } on Object {
      // Best-effort.
    }
  }

  /// Drops everything. For tests.
  void clear() {
    _entries.clear();
    _inflight.clear();
  }
}

/// A typed, keyed read through [QueryCache].
///
/// Screens create the [watch] stream once (e.g. in `initState`) and pass
/// [peek] as the `StreamBuilder`'s `initialData`, so a cached value is on
/// screen on the very first frame.
class CachedQuery<T> {
  CachedQuery({
    required this.key,
    required this.load,
    required this.encode,
    required this.decode,
    this.maxAge = const Duration(minutes: 5),
    QueryCache? cache,
  }) : _cache = cache ?? QueryCache.instance;

  final String key;
  final Future<T> Function() load;
  final Object? Function(T value) encode;
  final T Function(Object? json) decode;

  /// How long a cached value is shown without a background refresh.
  final Duration maxAge;

  final QueryCache _cache;

  /// The cached value, or null when there is none (or it no longer decodes,
  /// e.g. after a model change — treated as a cache miss).
  T? peek() {
    if (!_cache.contains(key)) return null;
    try {
      return decode(_cache.peek(key));
    } on Object {
      return null;
    }
  }

  /// Emits the cached value first (if any), then — unless that value is
  /// still within [maxAge] — the freshly loaded one. A failed refresh is an
  /// error only when there was nothing cached to show.
  Stream<T> watch() async* {
    final cached = peek();
    if (cached != null) {
      yield cached;
      if (_cache.isFresh(key, maxAge)) return;
    }
    try {
      yield await refresh();
    } on Object {
      if (cached == null) rethrow;
    }
  }

  /// Loads from the network and updates the cache.
  Future<T> refresh() async =>
      decode(await _cache.fetch(key, () async => encode(await load())));

  /// Warms the cache in the background; never throws.
  Future<void> prefetch() async {
    if (_cache.isFresh(key, maxAge)) return;
    try {
      await refresh();
    } on Object {
      // A failed prefetch just means the screen loads it itself.
    }
  }
}
