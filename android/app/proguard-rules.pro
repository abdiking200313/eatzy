# ProGuard/R8 rules for the release build (issue #46: enable code shrinking,
# resource shrinking, and obfuscation).
#
# getDefaultProguardFile("proguard-android-optimize.txt") (wired in
# build.gradle.kts alongside this file) already covers standard Android
# framework shrinking safety, and the Flutter Gradle plugin bundles its own
# consumer rules that keep the io.flutter.** embedding classes it needs.
# The rules below are this app's own additions, based on checking every
# plugin in pubspec.yaml (and its Android-side transitive deps, e.g.
# flutter_cache_manager -> sqflite/path_provider) for reflection use or a
# missing consumer-rules.pro as of 2026-09-15:
#
# - google_fonts, cached_network_image, go_router, intl, shared_preferences,
#   sqflite, path_provider, and supabase_flutter (plus its gotrue/postgrest/
#   realtime_client/storage_client dependencies) are either pure Dart or use
#   their Android platform channel classes without Java reflection, so they
#   need no extra keep rules under R8.
# - flutter_secure_storage's Android implementation
#   (com.it_nomads.fluttersecurestorage) talks to javax.crypto/AndroidKeyStore
#   directly rather than via reflection, but ships no consumer-rules.pro of
#   its own. It's kept defensively below since it backs Supabase auth session
#   persistence and a silent shrink there would be a hard-to-diagnose runtime
#   failure rather than a build error.

# Flutter's standard recommended keep rules for the embedding and generated
# plugin registrant, restated defensively (normally already covered by the
# Flutter Gradle plugin's own consumer rules).
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage: keep its Android Keystore-backed cipher classes.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Preserve line numbers and annotations for readable release stack traces
# once symbols are archived per docs/release.md.
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
