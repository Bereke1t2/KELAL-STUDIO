plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kelalstudio.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kelalstudio.app"
        // minSdk 24 (Android 7.0): the original decision was minSdk 21 for max
        // reach on low-end/older devices, but Flutter 3.44.4's own tooling
        // enforces a floor of 24 — it force-rewrites any lower value back to
        // `flutter.minSdkVersion` on every build (see
        // flutter/packages/flutter_tools/lib/src/android/migrations/
        // min_sdk_version_migration.dart upstream). Don't hardcode a literal
        // below 24 here; it will not survive the next `flutter build`/`run`.
        // See mobile/CLAUDE.md's decisions log.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add real release signing config before shipping — see
            // mobile/.claude/skills/flutter-security/SKILL.md.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
