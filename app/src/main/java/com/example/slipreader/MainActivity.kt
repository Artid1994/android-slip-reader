package com.example.slipreader

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.material.chip.ChipGroup
import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {

    private lateinit var tvHeaderDate: TextView
    private lateinit var tvNetBalance: TextView
    private lateinit var tvTotalIncome: TextView
    private lateinit var tvTotalExpense: TextView
    private lateinit var fabScan: ExtendedFloatingActionButton
    private lateinit var btnSelectFolder: Button
    private lateinit var tvFolderPath: TextView
    private lateinit var spInterval: Spinner
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

    private val selectFolderLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri: Uri? ->
        uri?.let {
            contentResolver.takePersistableUriPermission(
                it,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            repository.saveAutoFolderUri(it.toString())
            tvFolderPath.text = "แฟ้ม: ${it.path}"
            scheduleAutoScanWork()
            Toast.makeText(this, "ตั้งค่าแฟ้มตรวจสลิปเรียบร้อย", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        repository = TransactionRepository(this)

        tvHeaderDate = findViewById(R.id.tvHeaderDate)
        tvNetBalance = findViewById(R.id.tvNetBalance)
        tvTotalIncome = findViewById(R.id.tvTotalIncome)
        tvTotalExpense = findViewById(R.id.tvTotalExpense)
        fabScan = findViewById(R.id.fabScan)
        btnSelectFolder = findViewById(R.id.btnSelectFolder)
        tvFolderPath = findViewById(R.id.tvFolderPath)
        spInterval = findViewById(R.id.spInterval)
        etSearch = findViewById(R.id.etSearch)
        chipGroupFilter = findViewById(R.id.chipGroupFilter)
        rvHistory = findViewById(R.id.rvHistory)

        fabScan.setOnClickListener { pickImageLauncher.launch("image/*") }
        btnSelectFolder.setOnClickListener { selectFolderLauncher.launch(null) }

        repository.getAutoFolderUri()?.let {
            tvFolderPath.text = "แฟ้มที่เลือกไว้เรียบร้อย"
        }

        val intervals = arrayOf("ทุก 15 นาที", "ทุก 30 นาที", "ทุก 60 นาที")
        val spinnerAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, intervals)
        spInterval.adapter = spinnerAdapter

        spInterval.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val minutes = when (position) {
                    1 -> 30
                    2 -> 60
                    else -> 15
                }
                repository.saveScanInterval(minutes)
                scheduleAutoScanWork()
            }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        rvHistory.layoutManager = LinearLayoutManager(this)
        
        adapter = TransactionAdapter(emptyList()) { record ->
            showEditDeleteDialog(record)
        }
        rvHistory.adapter = adapter

        etSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                searchQuery = s.toString().trim()
                applyFilterAndSearch()
            }
            override fun afterTextChanged(s: Editable?) {}
        })

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

    private fun scheduleAutoScanWork() {
        val minutes = repository.getScanInterval().toLong()
        val workRequest = PeriodicWorkRequestBuilder<SlipAutoScanWorker>(minutes, TimeUnit.MINUTES).build()

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            "SlipAutoScanWork",
            ExistingPeriodicWorkPolicy.UPDATE,
            workRequest
        )
    }

    private fun showEditDeleteDialog(record: TransactionRecord) {
        val options = arrayOf("✏️ แก้ไขหมวดหมู่/ยอดเงิน", "🗑️ ลบรายการนี้")
        AlertDialog.Builder(this)
            .setTitle("${record.category} - ${record.amount} ฿")
            .setItems(options) { _, which ->
                if (which == 0) {
                    showEditDialog(record)
                } else {
                    repository.deleteTransaction(record.id)
                    Toast.makeText(this, "ลบรายการเรียบร้อย", Toast.LENGTH_SHORT).show()
                    updateUI()
                }
            }
            .show()
    }

    private fun showEditDialog(record: TransactionRecord) {
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(32, 16, 32, 16)
        }

        val etAmount = EditText(this).apply {
            hint = "ยอดเงิน"
            setText(record.amount.toString())
        }
        val etCategory = EditText(this).apply {
            hint = "หมวดหมู่"
            setText(record.category)
        }

        layout.addView(etAmount)
        layout.addView(etCategory)

        AlertDialog.Builder(this)
            .setTitle("แก้ไขรายการ")
            .setView(layout)
            .setPositiveButton("บันทึก") { _, _ ->
                val newAmount = etAmount.text.toString().toDoubleOrNull() ?: record.amount
                val newCategory = etCategory.text.toString().ifEmpty { record.category }
                val updatedRecord = record.copy(amount = newAmount, category = newCategory)
                
                repository.updateTransaction(updatedRecord)
                Toast.makeText(this, "อัปเดตข้อมูลเรียบร้อย", Toast.LENGTH_SHORT).show()
                updateUI()
            }
            .setNegativeButton("ยกเลิก", null)
            .show()
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
