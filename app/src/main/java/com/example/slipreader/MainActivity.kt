package com.example.slipreader

import android.net.Uri
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.chip.ChipGroup
import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MainActivity : AppCompatActivity() {

    private lateinit var tvHeaderDate: TextView
    private lateinit var tvNetBalance: TextView
    private lateinit var tvTotalIncome: TextView
    private lateinit var tvTotalExpense: TextView
    private lateinit var fabScan: ExtendedFloatingActionButton
    private lateinit var etSearch: EditText
    private lateinit var chipGroupFilter: ChipGroup
    private lateinit var rvHistory: RecyclerView
    private lateinit var adapter: TransactionAdapter
    private lateinit var repository: TransactionRepository

    private var currentFilterType: String = "ALL"
    private var searchQuery: String = ""

    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { processSlipImage(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        repository = TransactionRepository(this)

        // Binding UI Elements
        tvHeaderDate = findViewById(R.id.tvHeaderDate)
        tvNetBalance = findViewById(R.id.tvNetBalance)
        tvTotalIncome = findViewById(R.id.tvTotalIncome)
        tvTotalExpense = findViewById(R.id.tvTotalExpense)
        fabScan = findViewById(R.id.fabScan)
        etSearch = findViewById(R.id.etSearch)
        chipGroupFilter = findViewById(R.id.chipGroupFilter)
        rvHistory = findViewById(R.id.rvHistory)

        fabScan.setOnClickListener { pickImageLauncher.launch("image/*") }

        rvHistory.layoutManager = LinearLayoutManager(this)
        adapter = TransactionAdapter(emptyList())
        rvHistory.adapter = adapter

        // ค้นหา
        etSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                searchQuery = s.toString().trim()
                applyFilterAndSearch()
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        // ตัวกรอง
        chipGroupFilter.setOnCheckedStateChangeListener { _, checkedIds ->
            currentFilterType = when (checkedIds.firstOrNull()) {
                R.id.chipExpense -> "EXPENSE"
                R.id.chipIncome -> "INCOME"
                else -> "ALL"
            }
            applyFilterAndSearch()
        }

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

            tvHeaderDate.text = "📊 สรุปภาพรวม ($latestDate)"
            tvNetBalance.text = "฿ ${String.format("%.2f", summary.netBalance)}"
            tvTotalIncome.text = "+${summary.totalIncome} ฿"
            tvTotalExpense.text = "-${summary.totalExpense} ฿"

            applyFilterAndSearch()
        } else {
            tvHeaderDate.text = "📊 สรุปภาพรวมวันนี้"
            tvNetBalance.text = "฿ 0.00"
            tvTotalIncome.text = "+0.00 ฿"
            tvTotalExpense.text = "-0.00 ฿"
            adapter.updateData(emptyList())
        }
    }

    private fun applyFilterAndSearch() {
        var filteredList = repository.getAllTransactions()

        filteredList = when (currentFilterType) {
            "INCOME" -> filteredList.filter { it.type == TransactionType.INCOME }
            "EXPENSE" -> filteredList.filter { it.type == TransactionType.EXPENSE }
            else -> filteredList
        }

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
