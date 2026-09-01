#!/bin/bash

# สร้างโฟลเดอร์ .github/workflows หากยังไม่มี
mkdir -p .github/workflows

# อัปเดตไฟล์ android.yml เป็นเวอร์ชันล่าสุด รองรับ Node.js 24 และ setup-java@v5
cat << 'EOF' > .github/workflows/android.yml
name: Android CI

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Set up JDK 17
      uses: actions/setup-java@v5
      with:
        java-version: '17'
        distribution: 'temurin'
        cache: gradle

    - name: Grant execute permission for gradlew
      run: chmod +x gradlew

    - name: Build with Gradle
      run: ./gradlew assembleDebug --stacktrace

    - name: Upload APK Artifact
      uses: actions/upload-artifact@v4
      with:
        name: app-debug
        path: app/build/outputs/apk/debug/app-debug.apk
EOF

echo "✅ อัปเดตไฟล์ .github/workflows/android.yml เรียบร้อยแล้ว!"
