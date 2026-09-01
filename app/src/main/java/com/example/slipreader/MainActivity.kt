package com.example.slipreader

import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MainActivity : AppCompatActivity() {

    private lateinit var tvSummary: TextView
    private lateinit var tvHistory: TextView
    private lateinit var btnSelectImage: Button
    private lateinit var repository: TransactionRepository

    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { processSlipImage(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = TransactionRepository(this)

        val scrollView = ScrollView(this)
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }

        btnSelectImage = Button(this).apply {
            text = "สแกนสลิปโอนเงิน"
            setOnClickListener { pickImageLauncher.launch("image/*") }
        }

        tvSummary = TextView(this).apply {
            textSize = 16f
            setPadding(0, 24, 0, 24)
        }

        tvHistory = TextView(this).apply {
            textSize = 14f
            setPadding(0, 16, 0, 0)
        }

        layout.addView(btnSelectImage)
        layout.addView(tvSummary)
        layout.addView(tvHistory)
        scrollView.addView(layout)
        setContentView(scrollView)

        updateUI()
    }

    private fun processSlipImage(imageUri: Uri) {
        try {
            val image = InputImage.fromFilePath(this, imageUri)
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    val record = SlipParser.parse(visionText.text)
                    if (record != null) {
                        repository.saveTransaction(record)
                        Toast.makeText(this, "บันทึกข้อมูลสลิปเรียบร้อย", Toast.LENGTH_SHORT).show()
                        updateUI()
                    } else {
                        Toast.makeText(this, "ไม่สามารถแกะยอดเงินจากสลิปได้", Toast.LENGTH_SHORT).show()
                    }
                }
                .addOnFailureListener { e ->
                    Toast.makeText(this, "อ่านสลิปไม่สำเร็จ: ${e.message}", Toast.LENGTH_SHORT).show()
                }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateUI() {
        val historyList = repository.getAllTransactions()
        
        if (historyList.isNotEmpty()) {
            val latestDate = historyList.first().dateStr
            val summary = repository.getDailySummary(latestDate)

            tvSummary.text = """
                📊 === สรุปประจำวัน ($latestDate) ===
                🟢 รายรับรวม: ${summary.totalIncome} บาท
                🔴 รายจ่ายรวม: ${summary.totalExpense} บาท
                💵 ยอดสุทธิ: ${summary.netBalance} บาท (${summary.itemCount} รายการ)
            """.trimIndent()

            val historyText = StringBuilder("📜 === ประวัติการโอนเงิน (ล่าสุดขึ้นก่อน) ===\n\n")
            historyList.forEach { item ->
                val typeSymbol = if (item.type == TransactionType.INCOME) "🟢 +" else "🔴 -"
                historyText.append("$typeSymbol ${item.amount} บาท [${item.category}]\n")
                historyText.append("   🏦 ${item.bankName} | ผู้รับ: ${item.receiverName}\n")
                historyText.append("   📅 ${item.dateStr}  ⏰ ${item.timeStr}\n")
                historyText.append("----------------------------------------\n")
            }
            tvHistory.text = historyText.toString()
        } else {
            tvSummary.text = "ยังไม่มีข้อมูลประวัติธุรกรรม"
            tvHistory.text = ""
        }
    }
}
