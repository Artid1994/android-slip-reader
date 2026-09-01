package com.example.slipreader

data class SlipData(
    val amount: Double?,
    val date: String?,
    val time: String?,
    val rawText: String
)

object SlipParser {

    fun parse(rawText: String): SlipData {
        // 1. ดึงยอดเงิน (รองรับตัวเลขที่มี .00 และคำเพี้ยนต่อท้าย)
        val amountRegex = Regex("""([0-9,]+\.[0-9]{2})""")
        val amountMatch = amountRegex.findAll(rawText)
            .mapNotNull { it.value.replace(",", "").toDoubleOrNull() }
            .filter { it > 0.0 } // ตัดค่า 0.00 (ค่าธรรมเนียม) ออก
            .firstOrNull()

        // 2. ดึงวันที่ (รองรับรูปแบบ 10.8.69, 10/08/69, 10 ส.ค. 69)
        val dateRegex = Regex("""(\d{1,2}\s*[./-]\s*\d{1,2}\s*[./-]\s*\d{2,4}|\d{1,2}\s*(?:ม\.ค\.|ก\.พ\.|มี\.ค\.|เม\.ย\.|พ\.ค\.|มิ\.ย\.|ก\.ค\.|ส\.ค\.|ก\.ย\.|ต\.ค\.|พ\.ย\.|ธ\.ค\.)\s*\d{2,4})""")
        val dateMatch = dateRegex.find(rawText)
        val date = dateMatch?.groupValues?.get(1)?.replace(" ", "")

        // 3. ดึงเวลา (หาแพทเทิร์น HH:mm)
        val timeRegex = Regex("""([0-2]?\d:[0-5]\d)""")
        val timeMatch = timeRegex.find(rawText)
        val time = timeMatch?.groupValues?.get(1)

        return SlipData(
            amount = amountMatch,
            date = date,
            time = time,
            rawText = rawText
        )
    }
}
