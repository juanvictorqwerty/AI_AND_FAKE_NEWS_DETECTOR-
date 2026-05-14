plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Base64

val dartEnvironmentVariables = mutableMapOf<String, String>()
if (project.hasProperty("dart-defines")) {
    val dartDefines = project.property("dart-defines") as String
    dartDefines.split(",").forEach {
        try {
            val decoded = String(Base64.getDecoder().decode(it))
            val split = decoded.split("=")
            if (split.size == 2) {
                dartEnvironmentVariables[split[0]] = split[1]
            }
        } catch (e: IllegalArgumentException) {
            // Ignore malformed base64
        }
    }
}

android {
    namespace = "com.example.ai_fake_news_detector"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ai_fake_news_detector"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        buildConfigField("String", "FACT_CHECK_URL", "\"${dartEnvironmentVariables["NATIVE_FACT_CHECK_URL"] ?: "http://192.168.1.152:4000"}\"")
        buildConfigField("String", "MEDIA_UPLOAD_URL", "\"${dartEnvironmentVariables["NATIVE_MEDIA_UPLOAD_URL"] ?: "http://192.168.1.152:8000"}\"")
        manifestPlaceholders["customScheme"] = dartEnvironmentVariables["CUSTOM_SCHEME"] ?: "afnd"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // OkHttp for native HTTP requests
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    
    // Kotlin Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    
    // Gson for JSON parsing
    implementation("com.google.code.gson:gson:2.10.1")
    
    // AppCompat for AndroidX Activity support
    implementation("androidx.appcompat:appcompat:1.6.1")

    // Lifecycle runtime for lifecycleScope and lifecycle-aware components
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")

    // WorkManager for background processing
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    
    // AndroidX Core for notifications
    implementation("androidx.core:core-ktx:1.12.0")
}

flutter {
    source = "../.."
}
