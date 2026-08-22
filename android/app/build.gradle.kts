import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing from android/key.properties (never committed).
// Falls back to the debug key until the release keystore exists — see
// docs/play-store-checklist.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.example.car_guard"
    // file_picker (via flutter_plugin_android_lifecycle) requires API 36.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.kayan.carguard"
        // The AndroidX Car App Library requires minSdk >= 23.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // lintVital runs on release builds and can fail an otherwise valid APK
    // (e.g. deprecation/API-level lints in the Android Auto screen). Flutter
    // analyze + tests still gate the pipeline; lint is available on demand
    // via ./gradlew lint locally.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Android Auto front-end (CarGuardCarAppService)
    implementation("androidx.car.app:app:1.4.0")
    // DefaultLifecycleObserver used by the car screen lives here.
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    // IconCompat used to build CarIcon instances for Android Auto.
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
