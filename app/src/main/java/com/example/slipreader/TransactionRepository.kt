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
