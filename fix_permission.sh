#!/bin/bash

# 1. อัปเดต app/build.gradle.kts เป็น 1.0.0-beta1l (versionCode 13)
cat << 'EOF' > app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.slipreader"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.slipreader"
        minSdk = 24
        targetSdk = 34
        versionCode = 13
        versionName = "1.0.0-beta1l"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")

    // Google ML Kit & Gson & WorkManager
    implementation("com.google.mlkit:text-recognition:16.0.0")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.documentfile:documentfile:1.0.1")

    // MPAndroidChart
    implementation("com.github.PhilJay:MPAndroidChart:v3.1.0")
}
EOF

# 2. เพิ่มสิทธิ์ใน AndroidManifest.xml
cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="SlipReader"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.MaterialComponents.DayNight.NoActionBar">
        
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
EOF

# 3. อัปเดต MainActivity.kt เพิ่มการตรวจขอสิทธิ์ก่อนสแกน
cat << 'EOF' > app/src/main/java/com/example/slipreader/MainActivity.kt
package com.example.slipreader

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.documentfile.provider.DocumentFile
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.github.mikephil.charting.charts.PieChart
import com.github.mikephil.charting.data.PieData
import com.github.mikephil.charting.data.PieDataSet
import com.github.mikephil.charting.data.PieEntry
import com.google.android.material.chip.ChipGroup
import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton
import com.google.android.material.progressindicator.LinearProgressIndicator
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {

    private lateinit var tvHeaderDate: TextView
    private lateinit var tvNetBalance: TextView
    private lateinit var tvTotalIncome: TextView
    private lateinit var tvTotalExpense: TextView
    private lateinit var fabScan: ExtendedFloatingActionButton
    private lateinit var btnSelectFolder: Button
    private lateinit var btnRefreshNow: Button
    private lateinit var tvFolderPath: TextView
    private lateinit var etSearch: EditText
    private lateinit var chipGroupFilter: ChipGroup
    private lateinit var rvHistory: RecyclerView
    private lateinit var adapter: TransactionAdapter
    private lateinit var repository: TransactionRepository

    private lateinit var tvBudgetText: TextView
    private lateinit var progressBudget: LinearProgressIndicator
    private lateinit var pieChartCategory: PieChart

    private var currentFilterType: String = "ALL"
    private var searchQuery: String = ""
    private val monthlyBudget: Double = 10000.0

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            Toast.makeText(this, "ได้รับสิทธิ์เรียบร้อยแล้ว กดอัปเดตได้เลยครับ", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(this, "⚠️ กรุณาอนุญาตสิทธิ์เข้าถึงรูปภาพเพื่อใช้งานสแกนสลิป", Toast.LENGTH_LONG).show()
        }
    }

    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { processSlipImage(it) }
    }

    private val selectFolderLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri: Uri? ->
        uri?.let { folderUri ->
            val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            try {
                contentResolver.takePersistableUriPermission(folderUri, takeFlags)
            } catch (e: Exception) {
                e.printStackTrace()
            }

            repository.saveAutoFolderUri(folderUri.toString())
            tvFolderPath.text = "แฟ้ม: ${folderUri.path}"
            
            checkPermissionAndScan(folderUri)
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
        btnRefreshNow = findViewById(R.id.btnRefreshNow)
        tvFolderPath = findViewById(R.id.tvFolderPath)
        etSearch = findViewById(R.id.etSearch)
        chipGroupFilter = findViewById(R.id.chipGroupFilter)
        rvHistory = findViewById(R.id.rvHistory)

        tvBudgetText = findViewById(R.id.tvBudgetText)
        progressBudget = findViewById(R.id.progressBudget)
        pieChartCategory = findViewById(R.id.pieChartCategory)

        setupPieChart()

        fabScan.setOnClickListener { pickImageLauncher.launch("image/*") }
        
        btnSelectFolder.setOnClickListener {
            checkAndRequestPermission {
                selectFolderLauncher.launch(null)
            }
        }

        btnRefreshNow.setOnClickListener {
            val savedUriStr = repository.getAutoFolderUri()
            if (savedUriStr != null) {
                checkPermissionAndScan(Uri.parse(savedUriStr))
            } else {
                Toast.makeText(this, "กรุณาเลือกแฟ้มสลิปก่อนครับ", Toast.LENGTH_SHORT).show()
            }
        }

        repository.getAutoFolderUri()?.let {
            tvFolderPath.text = "แฟ้มที่เลือกไว้เรียบร้อย"
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

        // ตรวจสิทธิ์เมื่อเปิดแอป
        checkStoragePermissionSilent()

        updateUI()
    }

    private fun checkStoragePermissionSilent() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

        if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
            requestPermissionLauncher.launch(permission)
        }
    }

    private fun checkAndRequestPermission(onGranted: () -> Unit) {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

        if (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED) {
            onGranted()
        } else {
            requestPermissionLauncher.launch(permission)
        }
    }

    private fun checkPermissionAndScan(folderUri: Uri) {
        checkAndRequestPermission {
            scanFolderDirectly(folderUri)
        }
    }

    private fun setupPieChart() {
        pieChartCategory.isDrawHoleEnabled = true
        pieChartCategory.setHoleColor(Color.TRANSPARENT)
        pieChartCategory.holeRadius = 55f
        pieChartCategory.description.isEnabled = false
        pieChartCategory.legend.textColor = Color.WHITE
        pieChartCategory.setEntryLabelColor(Color.WHITE)
        pieChartCategory.setEntryLabelTextSize(10f)
    }

    private fun updateDashboardCharts(historyList: List<TransactionRecord>) {
        val expenseList = historyList.filter { it.type == TransactionType.EXPENSE }
        val totalExpense = expenseList.sumOf { it.amount }

        val percent = if (monthlyBudget > 0) ((totalExpense / monthlyBudget) * 100).toInt().coerceIn(0, 100) else 0
        progressBudget.progress = percent
        tvBudgetText.text = "${String.format("%.2f", totalExpense)} / ${monthlyBudget.toInt()} ฿ ($percent%)"

        when {
            percent >= 90 -> progressBudget.setIndicatorColor(Color.parseColor("#E57373"))
            percent >= 70 -> progressBudget.setIndicatorColor(Color.parseColor("#FFB74D"))
            else -> progressBudget.setIndicatorColor(Color.parseColor("#81C784"))
        }

        val categoryGroup = expenseList.groupBy { it.category }
        val entries = ArrayList<PieEntry>()

        for ((category, items) in categoryGroup) {
            val catTotal = items.sumOf { it.amount }.toFloat()
            entries.add(PieEntry(catTotal, category))
        }

        if (entries.isNotEmpty()) {
            val dataSet = PieDataSet(entries, "")
            dataSet.colors = listOf(
                Color.parseColor("#FF6B6B"),
                Color.parseColor("#4ECDC4"),
                Color.parseColor("#FFE66D"),
                Color.parseColor("#1A535C"),
                Color.parseColor("#F7FFF7")
            )
            dataSet.valueTextColor = Color.WHITE
            dataSet.valueTextSize = 12f

            val data = PieData(dataSet)
            pieChartCategory.data = data
            pieChartCategory.invalidate()
        } else {
            pieChartCategory.clear()
        }
    }

    private fun scanFolderDirectly(folderUri: Uri) {
        Toast.makeText(this, "กำลังสแกนรูปสลิปในแฟ้ม...", Toast.LENGTH_SHORT).show()
        
        lifecycleScope.launch(Dispatchers.IO) {
            val folder = DocumentFile.fromTreeUri(applicationContext, folderUri)
            if (folder != null) {
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                scanRecursive(folder, recognizer)
            }
            withContext(Dispatchers.Main) {
                updateUI()
                Toast.makeText(this@MainActivity, "อัปเดตสแกนสลิปเรียบร้อยแล้ว!", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun scanRecursive(docFile: DocumentFile, recognizer: com.google.mlkit.vision.text.TextRecognizer) {
        if (docFile.isDirectory) {
            for (file in docFile.listFiles()) {
                scanRecursive(file, recognizer)
            }
        } else if (docFile.isFile) {
            val name = docFile.name?.lowercase() ?: ""
            val type = docFile.type?.lowercase() ?: ""
            if (type.startsWith("image/") || name.endsWith(".jpg") || name.endsWith(".png") || name.endsWith(".jpeg")) {
                try {
                    contentResolver.openInputStream(docFile.uri)?.use { inputStream ->
                        val bitmap = BitmapFactory.decodeStream(inputStream)
                        if (bitmap != null) {
                            val image = InputImage.fromBitmap(bitmap, 0)
                            val visionText = com.google.android.gms.tasks.Tasks.await(recognizer.process(image))
                            if (visionText != null) {
                                SlipParser.parse(visionText.text)?.let { record ->
                                    repository.saveTransaction(record)
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
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

            updateDashboardCharts(historyList)
            applyFilterAndSearch()
        } else {
            tvHeaderDate.text = "📊 สรุปภาพรวมวันนี้"
            tvNetBalance.text = "฿ 0.00"
            tvTotalIncome.text = "+0.00 ฿"
            tvTotalExpense.text = "-0.00 ฿"
            updateDashboardCharts(emptyList())
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
EOF

echo "✅ เพิ่มระบบตรวจ/ขอสิทธิ์เข้าถึงสื่อและรูปภาพใน 1.0.0-beta1l เรียบร้อย!"
