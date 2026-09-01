#!/bin/bash

# 1. อัปเดต app/build.gradle.kts เป็น versionCode 21 (1.0.0-beta1t)
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
        versionCode = 21
        versionName = "1.0.0-beta1t"
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

    // Google ML Kit Text Recognition
    implementation("com.google.mlkit:text-recognition:16.0.0")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("com.github.PhilJay:MPAndroidChart:v3.1.0")
}
EOF

# 2. ปรับปรุง SlipParser.kt ให้แกะชื่อผู้รับ/ผู้ส่ง ภาษาไทยและสลิปทุกธนาคารได้อย่างแม่นยำ
cat << 'EOF' > app/src/main/java/com/example/slipreader/SlipParser.kt
package com.example.slipreader

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class TransactionType { INCOME, EXPENSE }

data class TransactionRecord(
    val id: String = System.currentTimeMillis().toString(),
    val amount: Double,
    val dateStr: String,
    val timeStr: String,
    val timestamp: Long,
    val bankName: String,
    val receiverName: String,
    val type: TransactionType,
    val category: String,
    val rawText: String
)

object SlipParser {

    fun parse(rawText: String): TransactionRecord? {
        val amountRegex = Regex("""([0-9,]+\.[0-9]{2})""")
        val amount = amountRegex.findAll(rawText)
            .mapNotNull { it.value.replace(",", "").toDoubleOrNull() }
            .filter { it > 0.0 }
            .firstOrNull() ?: return null

        val timeRegex = Regex("""([0-2]?\d:[0-5]\d)""")
        val timeStr = timeRegex.find(rawText)?.groupValues?.get(1) ?: "00:00"

        val dateRegex = Regex("""(\d{1,2}\s*[./-]\s*\d{1,2}\s*[./-]\s*\d{2,4}|\d{1,2}\s*(?:ม\.ค\.|ก\.พ\.|มี\.ค\.|เม\.ย\.|พ\.ค\.|มิ\.ย\.|ก\.ค\.|ส\.ค\.|ก\.ย\.|ต\.ค\.|พ\.ย\.|ธ\.ค\.)\s*\d{2,4})""")
        val rawDateMatch = dateRegex.find(rawText)?.groupValues?.get(1)?.replace(" ", "")
        
        val dateStr = if (rawDateMatch != null) {
            rawDateMatch
        } else {
            SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        }

        val bankName = when {
            rawText.contains("K+", ignoreCase = true) || rawText.contains("KBANK", ignoreCase = true) || rawText.contains("กสิกร", ignoreCase = true) -> "กสิกรไทย (KBank)"
            rawText.contains("SCB", ignoreCase = true) || rawText.contains("แม่มณี", ignoreCase = true) || rawText.contains("ไทยพาณิชย์", ignoreCase = true) -> "ไทยพาณิชย์ (SCB)"
            rawText.contains("Krungthai", ignoreCase = true) || rawText.contains("KTB", ignoreCase = true) || rawText.contains("กรุงไทย", ignoreCase = true) -> "กรุงไทย (KTB)"
            rawText.contains("Bangkok", ignoreCase = true) || rawText.contains("BBL", ignoreCase = true) || rawText.contains("กรุงเทพ", ignoreCase = true) -> "กรุงเทพ (BBL)"
            rawText.contains("TTB", ignoreCase = true) || rawText.contains("TMB", ignoreCase = true) -> "ทหารไทยธนชาต (ttb)"
            else -> "ไม่ระบุธนาคาร"
        }

        // Regex ครอบคลุมการแกะชื่อผู้รับ/ผู้ส่งของ KBank, SCB, KTB, BBL, PromptPay
        val receiverRegex = Regex("""(?:ไปยัง|To|ผู้รับ|ผู้รับเงิน|โอนให้|เข้าบัญชี|ร้าน|SHOP|ชื่อบัญชี)\s*:?\s*([A-Za-z0-9ก-๙\s\.\-]{3,35})""", RegexOption.IGNORE_CASE)
        var receiverName = receiverRegex.find(rawText)?.groupValues?.get(1)?.trim()

        if (receiverName.isNullOrEmpty()) {
            val prefixRegex = Regex("""((?:นาย|นาง|นางสาว|บจก\.|หจก\.|ร้าน|บริษัท|บมจ\.)\s*[A-Za-z0-9ก-๙\s\.\-]{3,30})""")
            receiverName = prefixRegex.find(rawText)?.groupValues?.get(1)?.trim()
        }

        val finalReceiver = receiverName?.replace("\n", " ")?.trim() ?: "ไม่ทราบชื่อผู้รับ"

        val type = if (rawText.contains("รับเงิน", ignoreCase = true) || rawText.contains("Received", ignoreCase = true) || rawText.contains("เงินเข้า", ignoreCase = true)) {
            TransactionType.INCOME
        } else {
            TransactionType.EXPENSE
        }

        val category = when {
            rawText.contains("SHOP", ignoreCase = true) || rawText.contains("ร้าน", ignoreCase = true) || rawText.contains("7-Eleven", ignoreCase = true) || rawText.contains("CJ", ignoreCase = true) -> "ช้อปปิ้ง/ของใช้"
            rawText.contains("Food", ignoreCase = true) || rawText.contains("อาหาร", ignoreCase = true) || rawText.contains("Grab", ignoreCase = true) || rawText.contains("Lineman", ignoreCase = true) -> "อาหาร/เครื่องดื่ม"
            rawText.contains("เติมน้ำมัน", ignoreCase = true) || rawText.contains("PTT", ignoreCase = true) || rawText.contains("Bangchak", ignoreCase = true) || rawText.contains("Shell", ignoreCase = true) -> "เดินทาง/น้ำมัน"
            else -> if (type == TransactionType.INCOME) "รายรับทั่วไป" else "รายจ่ายทั่วไป"
        }

        return TransactionRecord(
            id = System.currentTimeMillis().toString(),
            amount = amount,
            dateStr = dateStr,
            timeStr = timeStr,
            timestamp = System.currentTimeMillis(),
            bankName = bankName,
            receiverName = finalReceiver,
            type = type,
            category = category,
            rawText = rawText
        )
    }
}
EOF

echo "✅ ปรับปรุงการสกัดชื่อผู้รับและอัปเดตสคริปต์สำเร็จแล้ว!"
