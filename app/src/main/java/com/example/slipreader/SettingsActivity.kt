package com.example.slipreader

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class SettingsActivity : AppCompatActivity() {

    private lateinit var etMonthlyBudget: EditText
    private lateinit var btnSaveSettings: Button
    private lateinit var repository: TransactionRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        repository = TransactionRepository(this)
        etMonthlyBudget = findViewById(R.id.etMonthlyBudget)
        btnSaveSettings = findViewById(R.id.btnSaveSettings)

        // โหลดค่างบประมาณที่บันทึกไว้
        etMonthlyBudget.setText(repository.getMonthlyBudget().toString())

        btnSaveSettings.setOnClickListener {
            val budget = etMonthlyBudget.text.toString().toDoubleOrNull() ?: 10000.0
            repository.saveMonthlyBudget(budget)
            Toast.makeText(this, "บันทึกการตั้งค่าเรียบร้อยแล้ว", Toast.LENGTH_SHORT).show()
            finish()
        }
    }
}
