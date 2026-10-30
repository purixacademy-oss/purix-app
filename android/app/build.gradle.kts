
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
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

            if (!jks.exists()) {
                throw GradleException("Release JKS file is missing!")
            }

            storeFile = jks
            storePassword = System.getenv("KEYSTORE_PASSWORD")
                ?: throw GradleException("KEYSTORE_PASSWORD secret missing!")

            keyAlias = System.getenv("KEY_ALIAS")
                ?: throw GradleException("KEY_ALIAS secret missing!")

            keyPassword = System.getenv("KEY_PASSWORD")
                ?: throw GradleException("KEY_PASSWORD secret missing!")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
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
