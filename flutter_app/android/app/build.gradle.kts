import java.io.FileInputStream
import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Processes google-services.json into the resources firebase_core needs
    // (issue #47). Must come after the Android application plugin above.
    id("com.google.gms.google-services")
    // Uploads crash/error reports (and, for a minified release build, the
    // mapping file needed to de-obfuscate stack traces) at build time
    // (issue #287). Must come after google-services above, per the
    // FlutterFire Crashlytics setup docs.
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.zivo.app"
    // Pinned to literal values instead of flutter.* so build output does not
    // depend on whichever Flutter toolchain the builder has installed.
    // These match the Flutter 3.41.9 template defaults (see .fvmrc).
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zivo.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signs with the real upload key once android/key.properties (see
            // android/SIGNING.md) points at one — Play Store rejects
            // debug-signed artifacts outright. Falls back to the debug key
            // only when no key.properties exists, so `flutter run --release`
            // keeps working without one (issue #32).
            signingConfig =
                if (hasKeystoreProperties) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }

            // Code shrinking, resource shrinking, and obfuscation (issue #46).
            // shrinkResources requires minifyEnabled to also be true.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
