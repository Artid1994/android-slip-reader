package com.example.slipreader

import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MainActivity : AppCompatActivity() {

    private lateinit var tvSummary: TextView
    private lateinit var btnSelectImage: Button
    private lateinit var rvHistory: RecyclerView
    private lateinit var adapter: TransactionAdapter
    private lateinit var repository: TransactionRepository

    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { processSlipImage(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = TransactionRepository(this)

        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(16, 32, 16, 16)
        }

        btnSelectImage = Button(this).apply {
            text = "📷 สแกนสลิปโอนเงิน"
            setOnClickListener { pickImageLauncher.launch("image/*") }
        }

        tvSummary = TextView(this).apply {
            textSize = 15f
            setPadding(16, 24, 16, 24)
        }

        rvHistory = RecyclerView(this).apply {
            layoutManager = LinearLayoutManager(this@MainActivity)
        }

        adapter = TransactionAdapter(emptyList())
        rvHistory.adapter = adapter

        layout.addView(btnSelectImage)
        layout.addView(tvSummary)
        layout.addView(rvHistory)
        setContentView(layout)

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
                        Toast.makeText(this, "บันทึกสลิปสำเร็จ", Toast.LENGTH_SHORT).show()
                        updateUI()
                    } else {
                        Toast.makeText(this, "ไม่สามารถแกะยอดเงินได้", Toast.LENGTH_SHORT).show()
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
                📊 สรุปประจำวัน ($latestDate)
                🟢 รายรับ: ${summary.totalIncome} ฿  |  🔴 รายจ่าย: ${summary.totalExpense} ฿
                💵 สุทธิ: ${summary.netBalance} ฿ (${summary.itemCount} รายการ)
            """.trimIndent()

            adapter.updateData(historyList)
        } else {
            tvSummary.text = "ยังไม่มีข้อมูลประวัติธุรกรรม"
            adapter.updateData(emptyList())
        }
    }
}
