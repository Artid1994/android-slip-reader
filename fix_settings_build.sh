#!/bin/bash

# 1. อัปเดต TransactionRepository.kt เพิ่มระบบจัดการ Budget และ Shared Preferences
cat << 'EOF' > app/src/main/java/com/example/slipreader/TransactionRepository.kt
package com.example.slipreader

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class TransactionRepository(context: Context) {

    private val prefs = context.getSharedPreferences("slip_history_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()

    // บันทึกรายการใหม่
    fun saveTransaction(record: TransactionRecord): Boolean {
        val currentList = getAllTransactions().toMutableList()
        if (currentList.any { it.id == record.id }) {
            return false // รายการซ้ำ
        }
        currentList.add(0, record)
        saveList(currentList)
        return true
    }

    // ดึงรายการทั้งหมด
    fun getAllTransactions(): List<TransactionRecord> {
        val json = prefs.getString("transactions_key", null) ?: return emptyList()
        val type = object : TypeToken<List<TransactionRecord>>() {}.type
        val list: List<TransactionRecord> = gson.fromJson(json, type) ?: emptyList()
        return list.sortedByDescending { it.timestamp }
    }

    // จัดการงบประมาณรายเดือน (Monthly Budget)
    fun getMonthlyBudget(): Double {
        return prefs.getFloat("monthly_budget_key", 10000.0f).toDouble()
    }

    fun saveMonthlyBudget(budget: Double) {
        prefs.edit().putFloat("monthly_budget_key", budget.toFloat()).apply()
    }

    // ลบรายการ
    fun deleteTransaction(id: String) {
        val currentList = getAllTransactions().toMutableList()
        currentList.removeAll { it.id == id }
        saveList(currentList)
    }

    // แก้ไขรายการ
    fun updateTransaction(updatedRecord: TransactionRecord) {
        val currentList = getAllTransactions().toMutableList()
        val index = currentList.indexOfFirst { it.id == updatedRecord.id }
        if (index != -1) {
            currentList[index] = updatedRecord
            saveList(currentList)
        }
    }

    // จัดการ URI แฟ้มสลิปอัตโนมัติ
    fun saveAutoFolderUri(uriStr: String) {
        prefs.edit().putString("auto_folder_uri", uriStr).apply()
    }

    fun getAutoFolderUri(): String? {
        return prefs.getString("auto_folder_uri", null)
    }

    // คำนวณสรุปยอดประจำวัน
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

# 2. อัปเดต SettingsActivity.kt ให้เรียกใช้ Repository
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

        // โหลดค่างบประมาณที่บันทึกไว้
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

echo "✅ อัปเดตไฟล์ TransactionRepository.kt และ SettingsActivity.kt สมบูรณ์แล้ว!"
