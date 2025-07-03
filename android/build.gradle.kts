// ✅ Add Firebase plugin classpath
buildscript {
    // It's common for Flutter to define Kotlin version as an extra property
    // You might need to adjust this based on your project's actual Kotlin version
    val flutterKotlinVersion by extra("1.9.23") // Example: Use a recent, common Kotlin version for Flutter
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1") // Example version, ensure compatibility
        // Uncommented and using example versions. Verify these are compatible with your Flutter SDK and project.
        classpath("com.android.tools.build:gradle:8.2.0") // Example AGP version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$flutterKotlinVersion")
    }
}

// ✅ Repository configuration for all project modules
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Custom build directory settings
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ clean task definition
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
