package com.example.slipreader

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class TransactionType { INCOME, EXPENSE }

data class TransactionRecord(
    val id: Long = System.currentTimeMillis(),
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
        // 1. ดึงยอดเงิน
        val amountRegex = Regex("""([0-9,]+\.[0-9]{2})""")
        val amount = amountRegex.findAll(rawText)
            .mapNotNull { it.value.replace(",", "").toDoubleOrNull() }
            .filter { it > 0.0 }
            .firstOrNull() ?: return null

        // 2. ดึงเวลา (HH:mm)
        val timeRegex = Regex("""([0-2]?\d:[0-5]\d)""")
        val timeStr = timeRegex.find(rawText)?.groupValues?.get(1) ?: "00:00"

        // 3. ดึงวันที่จากสลิป (เช่น 10 ส.ค. 67, 10/08/2024, 10.08.67)
        val dateRegex = Regex("""(\d{1,2}\s*[./-]\s*\d{1,2}\s*[./-]\s*\d{2,4}|\d{1,2}\s*(?:ม\.ค\.|ก\.พ\.|มี\.ค\.|เม\.ย\.|พ\.ค\.|มิ\.ย\.|ก\.ค\.|ส\.ค\.|ก\.ย\.|ต\.ค\.|พ\.ย\.|ธ\.ค\.)\s*\d{2,4})""")
        val rawDateMatch = dateRegex.find(rawText)?.groupValues?.get(1)?.replace(" ", "")
        
        val dateStr = if (rawDateMatch != null) {
            rawDateMatch
        } else {
            SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        }

        // 4. ระบุธนาคาร
        val bankName = when {
            rawText.contains("K+", ignoreCase = true) || rawText.contains("KBANK", ignoreCase = true) || rawText.contains("กสิกร", ignoreCase = true) -> "กสิกรไทย (KBank)"
            rawText.contains("SCB", ignoreCase = true) || rawText.contains("แม่มณี", ignoreCase = true) || rawText.contains("ไทยพาณิชย์", ignoreCase = true) -> "ไทยพาณิชย์ (SCB)"
            rawText.contains("Krungthai", ignoreCase = true) || rawText.contains("KTB", ignoreCase = true) || rawText.contains("กรุงไทย", ignoreCase = true) -> "กรุงไทย (KTB)"
            rawText.contains("Bangkok", ignoreCase = true) || rawText.contains("BBL", ignoreCase = true) || rawText.contains("กรุงเทพ", ignoreCase = true) -> "กรุงเทพ (BBL)"
            rawText.contains("TTB", ignoreCase = true) || rawText.contains("TMB", ignoreCase = true) -> "ทหารไทยธนชาต (ttb)"
            else -> "ไม่ระบุธนาคาร"
        }

        // 5. แกะชื่อผู้รับโอน (ดึงบรรทัดถัดจากคำว่า ไปยัง / To / ผู้รับโอน หรือคำนำหน้าชื่อ)
        val receiverRegex = Regex("""(?:ไปยัง|To|ผู้รับ|โอนให้|ร้าน|SHOP)\s*:?\s*([A-Za-z0-9ก-๙\s\.\-]{3,30})""", RegexOption.IGNORE_CASE)
        var receiverName = receiverRegex.find(rawText)?.groupValues?.get(1)?.trim()

        if (receiverName.isNull_Empty()) {
            // สำรอง: จับชื่อที่มีคำนำหน้า นาย/นาง/นางสาว/บจก./หจก.
            val prefixRegex = Regex("""((?:นาย|นาง|นางสาว|บจก\.|หจก\.|ร้าน)\s*[A-Za-z0-9ก-๙\s]{3,25})""")
            receiverName = prefixRegex.find(rawText)?.groupValues?.get(1)?.trim()
        }

        val finalReceiver = receiverName ?: "ไม่ทราบชื่อผู้รับ"

        // 6. แยกประเภท เงินเข้า / เงินออก
        val type = if (rawText.contains("รับเงิน", ignoreCase = true) || rawText.contains("Received", ignoreCase = true) || rawText.contains("เงินเข้า", ignoreCase = true)) {
            TransactionType.INCOME
        } else {
            TransactionType.EXPENSE
        }

        // 7. จัดหมวดหมู่อัตโนมัติ
        val category = when {
            rawText.contains("SHOP", ignoreCase = true) || rawText.contains("ร้าน", ignoreCase = true) || rawText.contains("7-Eleven", ignoreCase = true) || rawText.contains("CJ", ignoreCase = true) -> "ช้อปปิ้ง/ของใช้"
            rawText.contains("Food", ignoreCase = true) || rawText.contains("อาหาร", ignoreCase = true) || rawText.contains("Grab", ignoreCase = true) || rawText.contains("Lineman", ignoreCase = true) -> "อาหาร/เครื่องดื่ม"
            rawText.contains("เติมน้ำมัน", ignoreCase = true) || rawText.contains("PTT", ignoreCase = true) || rawText.contains("Bangchak", ignoreCase = true) || rawText.contains("Shell", ignoreCase = true) -> "เดินทาง/น้ำมัน"
            else -> if (type == TransactionType.INCOME) "รายรับทั่วไป" else "รายจ่ายทั่วไป"
        }

        return TransactionRecord(
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

    private fun String?.isNull_Empty(): Boolean = this == null || this.trim().isEmpty()
}
