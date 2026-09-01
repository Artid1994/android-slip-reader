package com.example.slipreader

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class TransactionRepository(context: Context) {

    private val prefs = context.getSharedPreferences("slip_history_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()

    // บันทึกรายการใหม่ (คืนค่า true ถ้าบันทึกสำเร็จ, false ถ้าเป็นสลิปซ้ำ)
    fun saveTransaction(record: TransactionRecord): Boolean {
        val currentList = getAllTransactions().toMutableList()

        // ตรวจสอบว่าสลิปนี้เคยถูกบันทึกไปแล้วหรือยัง (เช็ก วันที่ + เวลา + ยอดเงิน)
        if (isDuplicate(record, currentList)) {
            return false // เป็นสลิปซ้ำ ไม่บันทึกเพิ่ม
        }

        currentList.add(0, record) // เพิ่มรายการล่าสุดไว้บนสุด
        saveList(currentList)
        return true
    }

    // ฟังก์ชันเช็กว่ามีรายการสลิปที่ ยอดเงิน, วันที่ และเวลา ตรงกันอยู่แล้วหรือไม่
    private fun isDuplicate(newRecord: TransactionRecord, existingList: List<TransactionRecord>): Boolean {
        return existingList.any { existing ->
            existing.amount == newRecord.amount &&
            existing.dateStr == newRecord.dateStr &&
            existing.timeStr == newRecord.timeStr
        }
    }

    // ดึงรายการทั้งหมด จัดลำดับตาม Timestamp (ล่าสุดขึ้นก่อน)
    fun getAllTransactions(): List<TransactionRecord> {
        val json = prefs.getString("transactions_key", null) ?: return emptyList()
        val type = object : TypeToken<List<TransactionRecord>>() {}.type
        val list: List<TransactionRecord> = gson.fromJson(json, type) ?: emptyList()
        return list.sortedByDescending { it.timestamp }
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
