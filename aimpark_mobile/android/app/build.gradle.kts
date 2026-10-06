import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Applied only when google-services.json is present, because the plugin hard-fails
// the build when it's missing. This keeps the app buildable before Firebase is
// configured — push simply stays inactive until the file is dropped in.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing key. In-app self-update (installing a newer APK over the
// current install) only works when every release is signed with the same
// certificate, so this must be a fixed file, never "whichever debug key this
// machine happens to have today". Loaded from key.properties (gitignored —
// see android/.gitignore) rather than committed.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.aimpark.aimpark_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (uses java.time APIs on older Android).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aimpark.aimpark_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase (firebase_core 4.x) requires at least API 23.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Left unsigned when key.properties is missing, rather than
            // falling back to the debug key — that silent fallback is exactly
            // what let release builds go out signed with an unpinned key in
            // the first place, which breaks in-app self-update the moment a
            // build comes from a different machine. See key.properties
            // (gitignored) and MD files/MOBILE_UPDATES.md.
            //
            // This is currently the same debug key as before (copied, not
            // regenerated) specifically so Google Sign-In's registered
            // certificate fingerprint doesn't change.
            //
            // Not an eager `throw` here: this block is evaluated during
            // Gradle's configuration phase for *every* invocation, including
            // an unrelated `assembleDebug` (e.g. mobile.yml's compile check),
            // which has no business needing a release signing key at all. The
            // loud failure for an actual signed-release attempt without the
            // key lives below, gated on the task graph instead.
            if (keyPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }

            // Release is minified by R8, which hard-fails on references it
            // cannot resolve — see proguard-rules.pro for what that hits here.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Fails loudly, rather than quietly producing an unsigned (or debug-signed)
// APK, specifically when the requested build actually needs the release
// signing key — never for an unrelated task like a debug compile check.
gradle.taskGraph.whenReady {
    val wantsSignedRelease = allTasks.any { task ->
        task.project == project &&
            (task.name.startsWith("assembleRelease") ||
                task.name.startsWith("bundleRelease") ||
                task.name.startsWith("packageRelease"))
    }
    if (wantsSignedRelease && !keyPropertiesFile.exists()) {
        throw GradleException(
            "android/key.properties is missing. Release builds must be signed " +
                "with the pinned release key — see MD files/MOBILE_UPDATES.md.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // FileProvider, used by the in-app updater (MainActivity.kt) to expose the
    // downloaded APK to the system installer. Declared directly rather than
    // relying on it coming in transitively through another plugin.
    implementation("androidx.core:core-ktx:1.15.0")
}
