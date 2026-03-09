plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gpp_fitness_tracker"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.gpp_fitness_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = findProperty("flutter.versionCode")?.toString()?.toInt() ?: 1
        versionName = findProperty("flutter.versionName")?.toString() ?: "1.0"
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17" // you can keep this for now
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
