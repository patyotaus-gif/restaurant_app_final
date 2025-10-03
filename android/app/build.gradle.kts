import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val hasReleaseKeystore = keystoreProperties.isNotEmpty()

android {
    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = (keystoreProperties["storeFile"] as? String)?.let { rootProject.file(it) }
                storePassword = keystoreProperties["storePassword"] as? String
                keyAlias = keystoreProperties["keyAlias"] as? String
                keyPassword = keystoreProperties["keyPassword"] as? String
            }
        }
    }

    namespace = "com.example.restaurant_app_final"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.restaurant_app_final"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.

        // --- FIX: Change this line ---
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Restaurant App Dev")
        }
        create("stg") {
            dimension = "environment"
            applicationIdSuffix = ".stg"
            versionNameSuffix = "-stg"
            resValue("string", "app_name", "Restaurant App Staging")
        }
        create("prod") {
            dimension = "environment"
            applicationIdSuffix = ".prod"
            versionNameSuffix = "-prod"
            resValue("string", "app_name", "Restaurant App")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
