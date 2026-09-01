#!/bin/bash

# 1. อัปเดต SlipParser.kt ให้ id เป็น String
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

        val receiverRegex = Regex("""(?:ไปยัง|To|ผู้รับ|โอนให้|ร้าน|SHOP)\s*:?\s*([A-Za-z0-9ก-๙\s\.\-]{3,30})""", RegexOption.IGNORE_CASE)
        var receiverName = receiverRegex.find(rawText)?.groupValues?.get(1)?.trim()

        if (receiverName.isNullOrEmpty()) {
            val prefixRegex = Regex("""((?:นาย|นาง|นางสาว|บจก\.|หจก\.|ร้าน)\s*[A-Za-z0-9ก-๙\s]{3,25})""")
            receiverName = prefixRegex.find(rawText)?.groupValues?.get(1)?.trim()
        }

        val finalReceiver = receiverName ?: "ไม่ทราบชื่อผู้รับ"

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

# 2. อัปเดต TransactionRepository.kt ให้การเปรียบเทียบ ID ใช้ String
cat << 'EOF' > app/src/main/java/com/example/slipreader/TransactionRepository.kt
package com.example.slipreader

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class TransactionRepository(context: Context) {

    private val prefs = context.getSharedPreferences("slip_history_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()

    fun saveTransaction(record: TransactionRecord): Boolean {
        val currentList = getAllTransactions().toMutableList()
        if (currentList.any { it.id == record.id }) {
            return false
        }
        currentList.add(0, record)
        saveList(currentList)
        return true
    }

    fun getAllTransactions(): List<TransactionRecord> {
        val json = prefs.getString("transactions_key", null) ?: return emptyList()
        val type = object : TypeToken<List<TransactionRecord>>() {}.type
        val list: List<TransactionRecord> = gson.fromJson(json, type) ?: emptyList()
        return list.sortedByDescending { it.timestamp }
    }

    fun getMonthlyBudget(): Double {
        return prefs.getFloat("monthly_budget_key", 10000.0f).toDouble()
    }

    fun saveMonthlyBudget(budget: Double) {
        prefs.edit().putFloat("monthly_budget_key", budget.toFloat()).apply()
    }

    fun deleteTransaction(id: String) {
        val currentList = getAllTransactions().toMutableList()
        currentList.removeAll { it.id == id }
        saveList(currentList)
    }

    fun updateTransaction(updatedRecord: TransactionRecord) {
        val currentList = getAllTransactions().toMutableList()
        val index = currentList.indexOfFirst { it.id == updatedRecord.id }
        if (index != -1) {
            currentList[index] = updatedRecord
            saveList(currentList)
        }
    }

    fun saveAutoFolderUri(uriStr: String) {
        prefs.edit().putString("auto_folder_uri", uriStr).apply()
    }

    fun getAutoFolderUri(): String? {
        return prefs.getString("auto_folder_uri", null)
    }

    fun getDailySummary(dateStr: String): DailySummary {
        val dailyList = getAllTransactions().filter { it.dateStr == dateStr }
        val totalIncome = dailyList.filter { it.type == TransactionType.INCOME }.sumOf { it.amount }
        val totalExpense = dailyList.filter { it.type == TransactionType.EXPENSE }.sumOf { it.amount }
        
        return DailySummary(
            dateStr = dateStr,
            totalIncome = totalIncome,
            totalExpense = totalExpense,
            netBalance = totalIncome - totalExpense,
            itemCount = dailyList.size
        )
    }

    private fun saveList(list: List<TransactionRecord>) {
        val json = gson.toJson(list)
        prefs.edit().putString("transactions_key", json).apply()
    }
}

data class DailySummary(
    val dateStr: String,
    val totalIncome: Double,
    val totalExpense: Double,
    val netBalance: Double,
    val itemCount: Int
)
EOF

echo "✅ แก้ไข Type Mismatch สำหรับ id (String) เรียบร้อยแล้ว!"
