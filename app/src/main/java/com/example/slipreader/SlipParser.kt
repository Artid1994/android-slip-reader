package com.example.slipreader

data class SlipData(
    val amount: Double?,
    val date: String?,
    val time: String?,
    val rawText: String
)

object SlipParser {

    fun parse(rawText: String): SlipData {
        // 1. ดึงยอดเงิน (หาแพทเทิร์น ตัวเลขที่มีจุดทศนิยม 2 ตำแหน่ง)
        val amountRegex = Regex("""(?:จำนวนเงิน|จำนวน|จำนวนเงินสุทธิ|บาท|Amount)?\s*:?\s*([0-9,]+\.[0-9]{2})""")
        val amountMatch = amountRegex.find(rawText)
        val amount = amountMatch?.groupValues?.get(1)?.replace(",", "")?.toDoubleOrNull()

        // 2. ดึงวันที่ (หาแพทเทิร์น DD/MM/YYYY หรือ DD ก.พ. YYYY)
        val dateRegex = Regex("""(\d{1,2}\s*(?:ม\.ค\.|ก\.พ\.|มี\.ค\.|เม\.ย\.|พ\.ค\.|มิ\.ย\.|ก\.ค\.|ส\.ค\.|ก\.ย\.|ต\.ค\.|พ\.ย\.|ธ\.ค\.|[/\.-])\s*\d{2,4})""")
        val dateMatch = dateRegex.find(rawText)
        val date = dateMatch?.groupValues?.get(1)

        // 3. ดึงเวลา (หาแพทเทิร์น HH:mm)
        val timeRegex = Regex("""([0-2]?\d:[0-5]\d)""")
        val timeMatch = timeRegex.find(rawText)
        val time = timeMatch?.groupValues?.get(1)

        return SlipData(
            amount = amount,
            date = date,
            time = time,
            rawText = rawText
        )
    }
}
