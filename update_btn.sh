#!/bin/bash

# 1. อัปเดต app/build.gradle.kts เป็น 1.0.0-beta1j
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
        versionCode = 11
        versionName = "1.0.0-beta1j"
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

# 2. ปรับเปลี่ยน activity_main.xml เปลี่ยน Spinner เป็น ปุ่ม "อัปเดต"
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.coordinatorlayout.widget.CoordinatorLayout 
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#121212">

    <androidx.core.widget.NestedScrollView
        android:layout_width="match_parent"
        android:layout_height="match_parent">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="vertical"
            android:paddingBottom="80dp">

            <!-- การ์ดสรุปยอดเงินสุทธิ -->
            <include layout="@layout/layout_summary_card" />

            <!-- การ์ด Budget Progress Bar -->
            <com.google.android.material.card.MaterialCardView
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginHorizontal="16dp"
                android:layout_marginBottom="12dp"
                app:cardBackgroundColor="#1E1E2C"
                app:cardCornerRadius="16dp"
                app:strokeWidth="0dp">

                <LinearLayout
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:orientation="vertical"
                    android:padding="16dp">

                    <LinearLayout
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:orientation="horizontal">

                        <TextView
                            android:layout_width="0dp"
                            android:layout_height="wrap_content"
                            android:layout_weight="1"
                            android:text="🎯 หลอดแจ้งเตือนงบประมาณเดือนนี้"
                            android:textColor="#FFFFFF"
                            android:textSize="13sp"
                            android:textStyle="bold" />

                        <TextView
                            android:id="@+id/tvBudgetText"
                            android:layout_width="wrap_content"
                            android:layout_height="wrap_content"
                            android:text="0.00 / 10,000 ฿ (0%)"
                            android:textColor="#A0A0B2"
                            android:textSize="12sp" />
                    </LinearLayout>

                    <com.google.android.material.progressindicator.LinearProgressIndicator
                        android:id="@+id/progressBudget"
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="10dp"
                        app:trackColor="#2C2C3E"
                        app:indicatorColor="#81C784"
                        app:trackCornerRadius="8dp"
                        app:trackThickness="10dp" />
                </LinearLayout>
            </com.google.android.material.card.MaterialCardView>

            <!-- การ์ด Donut Chart แสดงสัดส่วนรายจ่ายตามหมวดหมู่ -->
            <com.google.android.material.card.MaterialCardView
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginHorizontal="16dp"
                android:layout_marginBottom="12dp"
                app:cardBackgroundColor="#1E1E2C"
                app:cardCornerRadius="16dp"
                app:strokeWidth="0dp">

                <LinearLayout
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:orientation="vertical"
                    android:padding="16dp">

                    <TextView
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="🍩 สัดส่วนรายจ่ายตามหมวดหมู่"
                        android:textColor="#FFFFFF"
                        android:textSize="14sp"
                        android:textStyle="bold" />

                    <com.github.mikephil.charting.charts.PieChart
                        android:id="@+id/pieChartCategory"
                        android:layout_width="match_parent"
                        android:layout_height="220dp"
                        android:layout_marginTop="8dp" />
                </LinearLayout>
            </com.google.android.material.card.MaterialCardView>

            <!-- แถบเลือกโฟลเดอร์ & ปุ่มกดอัปเดตเดี๋ยวนี้ -->
            <com.google.android.material.card.MaterialCardView
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginHorizontal="16dp"
                android:layout_marginBottom="12dp"
                app:cardBackgroundColor="#1E1E2C"
                app:cardCornerRadius="12dp">

                <LinearLayout
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:orientation="vertical"
                    android:padding="12dp">

                    <LinearLayout
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:gravity="center_vertical"
                        android:orientation="horizontal">

                        <Button
                            android:id="@+id/btnSelectFolder"
                            style="@style/Widget.MaterialComponents.Button.OutlinedButton"
                            android:layout_width="0dp"
                            android:layout_height="wrap_content"
                            android:layout_weight="1"
                            android:text="📁 เลือกแฟ้มสลิปอัตโนมัติ"
                            android:textColor="#FFFFFF"
                            android:textSize="12sp" />

                        <Button
                            android:id="@+id/btnRefreshNow"
                            android:layout_width="wrap_content"
                            android:layout_height="wrap_content"
                            android:layout_marginStart="8dp"
                            android:backgroundTint="#2C2C3E"
                            android:text="🔄 อัปเดต"
                            android:textColor="#FFFFFF"
                            android:textSize="12sp" />
                    </LinearLayout>

                    <TextView
                        android:id="@+id/tvFolderPath"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="4dp"
                        android:text="ยังไม่ได้เลือกแฟ้มตรวจอัตโนมัติ"
                        android:textColor="#A0A0B2"
                        android:textSize="11sp" />
                </LinearLayout>
            </com.google.android.material.card.MaterialCardView>

            <!-- ช่องค้นหาและตัวกรอง -->
            <LinearLayout
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:orientation="vertical"
                android:paddingHorizontal="16dp">

                <EditText
                    android:id="@+id/etSearch"
                    android:layout_width="match_parent"
                    android:layout_height="44dp"
                    android:background="@android:drawable/editbox_background"
                    android:hint="🔍 ค้นหาผู้รับ ร้านค้า หรือหมวดหมู่..."
                    android:paddingHorizontal="16dp"
                    android:textColor="#FFFFFF"
                    android:textColorHint="#757575"
                    android:textSize="13sp" />

                <com.google.android.material.chip.ChipGroup
                    android:id="@+id/chipGroupFilter"
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:layout_marginTop="4dp"
                    app:singleSelection="true">

                    <com.google.android.material.chip.Chip
                        android:id="@+id/chipAll"
                        style="@style/Widget.MaterialComponents.Chip.Choice"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:checked="true"
                        android:text="ทั้งหมด" />

                    <com.google.android.material.chip.Chip
                        android:id="@+id/chipExpense"
                        style="@style/Widget.MaterialComponents.Chip.Choice"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="🔴 รายจ่าย" />

                    <com.google.android.material.chip.Chip
                        android:id="@+id/chipIncome"
                        style="@style/Widget.MaterialComponents.Chip.Choice"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="🟢 รายรับ" />
                </com.google.android.material.chip.ChipGroup>

            </LinearLayout>

            <!-- รายการประวัติ -->
            <androidx.recyclerview.widget.RecyclerView
                android:id="@+id/rvHistory"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:nestedScrollingEnabled="false"
                android:paddingTop="4dp" />

        </LinearLayout>
    </androidx.core.widget.NestedScrollView>

    <!-- ปุ่มสแกนสลิปแบบลอย (FAB) -->
    <com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton
        android:id="@+id/fabScan"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom|center_horizontal"
        android:layout_marginBottom="20dp"
        android:backgroundTint="#6200EE"
        android:text="📷 สแกนสลิปโอนเงิน"
        android:textColor="#FFFFFF"
        app:iconTint="#FFFFFF" />

</androidx.coordinatorlayout.widget.CoordinatorLayout>
EOF

# 3. อัปเดต MainActivity.kt ผูกเหตุการณ์คลิกปุ่ม "อัปเดต"
cat << 'EOF' > app/src/main/java/com/example/slipreader/MainActivity.kt
package com.example.slipreader

import android.content.Intent
import android.graphics.Color
import android.net.Uri
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
            
            scanFolderDirectly(folderUri)
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
        btnSelectFolder.setOnClickListener { selectFolderLauncher.launch(null) }

        // เมื่อกดปุ่ม "อัปเดต" ให้ทำการสแกนไฟล์ในแฟ้มทันที
        btnRefreshNow.setOnClickListener {
            val savedUriStr = repository.getAutoFolderUri()
            if (savedUriStr != null) {
                scanFolderDirectly(Uri.parse(savedUriStr))
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

        updateUI()
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
                Toast.makeText(this@MainActivity, "อัปเดตสแกนสลิปในแฟ้มเรียบร้อยแล้ว!", Toast.LENGTH_SHORT).show()
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
                    val image = InputImage.fromFilePath(applicationContext, docFile.uri)
                    com.google.android.gms.tasks.Tasks.await(recognizer.process(image))?.let { visionText ->
                        SlipParser.parse(visionText.text)?.let { record ->
                            repository.saveTransaction(record)
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

echo "✅ ไฟล์ถูกปรับเปลี่ยนเป็นปุ่มอัปเดตเดี๋ยวนี้เรียบร้อยแล้ว!"
