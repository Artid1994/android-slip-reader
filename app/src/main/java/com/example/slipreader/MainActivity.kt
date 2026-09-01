package com.example.slipreader

import android.net.Uri
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.chip.Chip
import com.google.android.material.chip.ChipGroup
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MainActivity : AppCompatActivity() {

    private lateinit var tvSummary: TextView
    private lateinit var btnSelectImage: Button
    private lateinit var etSearch: EditText
    private lateinit var chipGroupFilter: ChipGroup
    private lateinit var rvHistory: RecyclerView
    private lateinit var adapter: TransactionAdapter
    private lateinit var repository: TransactionRepository

    private var currentFilterType: String = "ALL" // ALL, INCOME, EXPENSE
    private var searchQuery: String = ""

    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { processSlipImage(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = TransactionRepository(this)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 32, 16, 16)
        }

        // ปุ่มสแกนสลิป
        btnSelectImage = Button(this).apply {
            text = "📷 สแกนสลิปโอนเงิน"
            setOnClickListener { pickImageLauncher.launch("image/*") }
        }

        // สรุปยอด
        tvSummary = TextView(this).apply {
            textSize = 15f
            setPadding(16, 16, 16, 16)
        }

        // ช่องค้นหา (Search Box)
        etSearch = EditText(this).apply {
            hint = "🔍 ค้นหาชื่อผู้รับ ร้านค้า หรือหมวดหมู่..."
            textSize = 14f
            setPadding(24, 20, 24, 20)
            setBackgroundResource(android.R.drawable.editbox_background)
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                    searchQuery = s.toString().trim()
                    applyFilterAndSearch()
                }
                override fun afterTextChanged(s: Editable?) {}
            })
        }

        // ตัวกรอง (Filter Chips)
        chipGroupFilter = ChipGroup(this).apply {
            isSingleSelection = true
            setPadding(0, 12, 0, 12)

            val chipAll = Chip(context).apply { text = "ทั้งหมด"; isChecked = true; id = 1 }
            val chipExpense = Chip(context).apply { text = "🔴 รายจ่าย"; id = 2 }
            val chipIncome = Chip(context).apply { text = "🟢 รายรับ"; id = 3 }

            addView(chipAll)
            addView(chipExpense)
            addView(chipIncome)

            setOnCheckedStateChangeListener { _, checkedIds ->
                currentFilterType = when (checkedIds.firstOrNull()) {
                    2 -> "EXPENSE"
                    3 -> "INCOME"
                    else -> "ALL"
                }
                applyFilterAndSearch()
            }
        }

        // รายการประวัติแบบ CardView
        rvHistory = RecyclerView(this).apply {
            layoutManager = LinearLayoutManager(this@MainActivity)
        }

        adapter = TransactionAdapter(emptyList())
        rvHistory.adapter = adapter

        layout.addView(btnSelectImage)
        layout.addView(tvSummary)
        layout.addView(etSearch)
        layout.addView(chipGroupFilter)
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
                        val isSaved = repository.saveTransaction(record)
                        if (isSaved) {
                            Toast.makeText(this, "บันทึกสลิปสำเร็จ", Toast.LENGTH_SHORT).show()
                            updateUI()
                        } else {
                            Toast.makeText(this, "⚠️ สลิปนี้เคยบันทึกไปแล้ว", Toast.LENGTH_LONG).show()
                        }
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

            applyFilterAndSearch()
        } else {
            tvSummary.text = "ยังไม่มีข้อมูลประวัติธุรกรรม"
            adapter.updateData(emptyList())
        }
    }

    // กรองข้อมูลตามคำค้นหาและชิปประเภทเงินเข้า-ออก
    private fun applyFilterAndSearch() {
        var filteredList = repository.getAllTransactions()

        // กรองตามประเภท (รายรับ / รายจ่าย)
        filteredList = when (currentFilterType) {
            "INCOME" -> filteredList.filter { it.type == TransactionType.INCOME }
            "EXPENSE" -> filteredList.filter { it.type == TransactionType.EXPENSE }
            else -> filteredList
        }

        // กรองตามคำค้นหา (Search Query)
        if (searchQuery.isNotEmpty()) {
            filteredList = filteredList.filter {
                it.receiverName.contains(searchQuery, ignoreCase = true) ||
                it.category.contains(searchQuery, ignoreCase = true) ||
                it.bankName.contains(searchQuery, ignoreCase = true)
            }
        }

        adapter.updateData(filteredList)
    }
}
