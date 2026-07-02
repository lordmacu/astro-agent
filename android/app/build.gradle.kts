plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
