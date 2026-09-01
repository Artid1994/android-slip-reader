#!/bin/bash

# 1. อัปเดต settings.gradle.kts ใส่ JitPack Repository
cat << 'EOF' > settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = java.net.URI("https://jitpack.io") }
    }
}

rootProject.name = "SlipReader"
include(":app")
EOF

# 2. อัปเดต app/build.gradle.kts เป็นเวอร์ชัน 1.0.0-beta1h (versionCode 9)
cat << 'EOF' > app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.slipreader"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.slipreader"
        minSdk = 24
        targetSdk = 34
        versionCode = 9
        versionName = "1.0.0-beta1h"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")

    // Google ML Kit & Gson & WorkManager
    implementation("com.google.mlkit:text-recognition:16.0.0")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.documentfile:documentfile:1.0.1")

    // MPAndroidChart
    implementation("com.github.PhilJay:MPAndroidChart:v3.1.0")
}
EOF

echo "✅ ไฟล์ถูกอัปเดตเรียบร้อยแล้ว!"
