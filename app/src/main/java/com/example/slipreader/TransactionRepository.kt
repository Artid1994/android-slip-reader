package com.example.slipreader

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File
import java.io.FileWriter

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

    // ฟังก์ชัน Export ข้อมูลประวัติเป็นไฟล์ CSV
    fun exportToCSV(): File? {
        val list = getAllTransactions()
        if (list.isEmpty()) return null

        val csvFile = File(context.getExternalFilesDir(null), "slip_transactions.csv")
        try {
            val writer = FileWriter(csvFile)
            writer.append("Date,Time,Type,Category,Amount,Bank,Receiver\n")
            for (item in list) {
                val typeStr = if (item.type == TransactionType.INCOME) "Income" else "Expense"
                writer.append("${item.dateStr},${item.timeStr},$typeStr,${item.category},${item.amount},${item.bankName},\"${item.receiverName}\"\n")
            }
            writer.flush()
            writer.close()
            return csvFile
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
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
