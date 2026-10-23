plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // 👇 NAYA ADD KIYA GAYA 👇
    id("com.google.gms.google-services") 
}

android {
    namespace = "com.purixacademy.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.purixacademy.app"
        minSdk = 23
        targetSdk = 34
        versionCode = 4
        versionName = "1.0.3"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    signingConfigs {
        create("release") {
            val jks = file("purix-release.jks")
            if (jks.exists()) {
                storeFile = jks
                storePassword = "purix@2026"
                keyAlias = "purixkey"
                keyPassword = "purix@2026"
            } else {
                val debugKeystore = file("debug.keystore")
                if (debugKeystore.exists()) {
                    storeFile = debugKeystore
                    storePassword = "android"
                    keyAlias = "androiddebugkey"
                    keyPassword = "android"
                }
            }
        }
    }
    
    buildTypes {
        getByName("release") {
            val jks = file("purix-release.jks")
            if (jks.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
    }
}

flutter {
    source = "../.."
}

dependencies {
    
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
}