#!/bin/bash

# 1. อัปเดต app/build.gradle.kts (versionCode 20, versionName 1.0.0-beta1s)
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
        versionCode = 20
        versionName = "1.0.0-beta1s"
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
    implementation("com.google.mlkit:text-recognition:16.0.0")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("com.github.PhilJay:MPAndroidChart:v3.1.0")
}
EOF

# 2. สร้าง Layout หน้าตั้งค่า (activity_settings.xml)
cat << 'EOF' > app/src/main/res/layout/activity_settings.xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#121212"
    android:orientation="vertical"
    android:padding="16dp">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="⚙️ ตั้งค่าแอปพลิเคชัน"
        android:textColor="#FFFFFF"
        android:textSize="20sp"
        android:textStyle="bold"
        android:layout_marginBottom="20dp" />

    <com.google.android.material.card.MaterialCardView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginBottom="12dp"
        app:cardBackgroundColor="#1E1E2C"
        app:cardCornerRadius="12dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="vertical"
            android:padding="16dp">

            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="💰 ตั้งค่างบประมาณรายเดือน (บาท)"
                android:textColor="#FFFFFF"
                android:textSize="14sp" />

            <EditText
                android:id="@+id/etMonthlyBudget"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginTop="8dp"
                android:inputType="numberDecimal"
                android:textColor="#FFFFFF"
                android:hint="เช่น 10000"
                android:textColorHint="#757575" />
        </LinearLayout>
    </com.google.android.material.card.MaterialCardView>

    <Button
        android:id="@+id/btnSaveSettings"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="💾 บันทึกการตั้งค่า"
        android:backgroundTint="#6200EE"
        android:textColor="#FFFFFF"
        android:layout_marginTop="16dp" />

</LinearLayout>
EOF

# 3. สร้าง SettingsActivity.kt
cat << 'EOF' > app/src/main/java/com/example/slipreader/SettingsActivity.kt
package com.example.slipreader

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class SettingsActivity : AppCompatActivity() {

    private lateinit var etMonthlyBudget: EditText
    private lateinit var btnSaveSettings: Button
    private lateinit var repository: TransactionRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        repository = TransactionRepository(this)
        etMonthlyBudget = findViewById(R.id.etMonthlyBudget)
        btnSaveSettings = findViewById(R.id.btnSaveSettings)

        etMonthlyBudget.setText(repository.getMonthlyBudget().toString())

        btnSaveSettings.setOnClickListener {
            val budget = etMonthlyBudget.text.toString().toDoubleOrNull() ?: 10000.0
            repository.saveMonthlyBudget(budget)
            Toast.makeText(this, "บันทึกการตั้งค่าเรียบร้อยแล้ว", Toast.LENGTH_SHORT).show()
            finish()
        }
    }
}
EOF

# 4. อัปเดต AndroidManifest.xml เพิ่ม SettingsActivity
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

        <activity
            android:name="com.example.slipreader.SettingsActivity"
            android:exported="false"
            android:label="ตั้งค่าแอป" />
    </application>

</manifest>
EOF

echo "✅ สคริปต์เตรียมไฟล์สร้างหน้าตั้งค่าเรียบร้อยแล้ว!"
