package com.example.slipreader

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class TransactionRepository(val context: Context) {

    private val prefs = context.getSharedPreferences("slip_history_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()

    fun saveTransaction(record: TransactionRecord): Boolean {
        val currentList = getAllTransactions().toMutableList()

        if (isDuplicate(record, currentList)) {
            return false
        }

        currentList.add(0, record)
        saveList(currentList)
        return true
    }

    // ลบรายการประวัติ
    fun deleteTransaction(id: Long) {
        val currentList = getAllTransactions().toMutableList()
        currentList.removeAll { it.id == id }
        saveList(currentList)
    }

    // แก้ไขรายการประวัติ
    fun updateTransaction(updatedRecord: TransactionRecord) {
        val currentList = getAllTransactions().toMutableList()
        val index = currentList.indexOfFirst { it.id == updatedRecord.id }
        if (index != -1) {
            currentList[index] = updatedRecord
            saveList(currentList)
        }
    }

    private fun isDuplicate(newRecord: TransactionRecord, existingList: List<TransactionRecord>): Boolean {
        return existingList.any { existing ->
            existing.amount == newRecord.amount &&
            existing.dateStr == newRecord.dateStr &&
            existing.timeStr == newRecord.timeStr
        }
    }

    fun getAllTransactions(): List<TransactionRecord> {
        val json = prefs.getString("transactions_key", null) ?: return emptyList()
        val type = object : TypeToken<List<TransactionRecord>>() {}.type
        val list: List<TransactionRecord> = gson.fromJson(json, type) ?: emptyList()
        return list.sortedByDescending { it.timestamp }
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

    // บันทึกและดึงพาธโฟลเดอร์สำหรับตรวจสลิปอัตโนมัติ
    fun saveAutoFolderUri(uriStr: String) {
        prefs.edit().putString("auto_folder_uri", uriStr).apply()
    }

    fun getAutoFolderUri(): String? {
        return prefs.getString("auto_folder_uri", null)
    }

    // บันทึกและดึงรอบเวลาสแกนสลิป (นาที)
    fun saveScanInterval(minutes: Int) {
        prefs.edit().putInt("scan_interval_minutes", minutes).apply()
    }

    fun getScanInterval(): Int {
        return prefs.getInt("scan_interval_minutes", 15) // Default 15 นาที
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
