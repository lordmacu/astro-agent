import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties (gitignored). When that
// file is absent (e.g. CI, a fresh clone) the release build falls back to the
// debug keys so `flutter build` still works — only locally-signed builds are
// upload-ready for the Play Store.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "ai.astro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ai.astro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Vosk (vosk_flutter_2) requires minSdk 30 (Android 11).
        minSdk = maxOf(flutter.minSdkVersion, 30)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Sign with the upload keystore when key.properties is present;
            // otherwise fall back to debug so CI / fresh clones still build.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    androidResources {
        noCompress += "tflite" // mmap models directly; don't gzip them in the APK
        noCompress += "onnx"   // wake-word models ship as .onnx
    }

    packaging {
        jniLibs {
            // vosk_flutter_2 and the vosk-android AAR both bundle these native
            // libs (we add the AAR to use org.vosk.* from Kotlin for the wake
            // word). Pick one instead of failing the merge.
            pickFirsts += "**/libvosk.so"
            pickFirsts += "**/libjnidispatch.so"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    // Offline Vosk for the native wake word (org.vosk.* API). The native libs
    // are already bundled by vosk_flutter_2; these AARs just expose the Java API
    // (duplicate .so handled by packaging.jniLibs.pickFirsts above).
    implementation("com.alphacephei:vosk-android:0.3.47@aar")
    implementation("net.java.dev.jna:jna:5.13.0@aar")
}
