#!/bin/bash

# 1. อัปเดต app/build.gradle.kts เป็น versionCode 17 (1.0.0-beta1p)
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
        versionCode = 17
        versionName = "1.0.0-beta1p"
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

# 2. แก้ไข AndroidManifest.xml กำหนด android namespace ให้ถูกต้องสมบูรณ์
cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

    <application
        android:allowBackup="true"
        android:label="SlipReader"
        android:supportsRtl="true"
        android:theme="@style/Theme.MaterialComponents.DayNight.NoActionBar">
        
        <activity
            android:name="com.example.slipreader.MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
EOF

echo "✅ แก้ไขไฟล์ XML Namespace ใน AndroidManifest.xml เรียบร้อย!"
