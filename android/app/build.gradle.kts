plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

fun localProperties(): Properties {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(localPropertiesFile.inputStream())
    }
    return properties
}

val flutterVersionCode = localProperties().getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
val flutterVersionName = localProperties().getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.upm.certrepository.digital_certificate_repository"
    // Ensuring compileSdk is driven by Flutter.
    // You can override this if strictly necessary, but it's generally best to let Flutter manage it.
    compileSdk = flutter.compileSdkVersion

    // Let Flutter manage ndkVersion.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        // Core library desugaring is enabled; ensure the dependency is correctly specified.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.upm.certrepository.digital_certificate_repository"
        // Ensuring minSdk is adequate for Firebase and other plugins.
        // Flutter's default is often lower, but many plugins require 21+.
        minSdk = 23 
        // Ensuring targetSdk is driven by Flutter.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Consider adding ProGuard/R8 rules for release builds.
            // minifyEnabled(true)
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    // Add the Firebase Authentication dependency
    implementation("com.google.firebase:firebase-auth")
    // Add the Cloud Firestore dependency
    implementation("com.google.firebase:firebase-firestore")
    // Add other Firebase dependencies as needed by your project (e.g., Storage, Messaging)
    // implementation("com.google.firebase:firebase-storage")
    // implementation("com.google.firebase:firebase-messaging")

    // Core library desugaring dependency, ensure version compatibility.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Standard Kotlin library
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:${rootProject.extra.get("flutterKotlinVersion")}")
}

// Apply the Google services plugin at the bottom of the file.
apply(plugin = "com.google.gms.google-services")
