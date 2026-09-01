package com.example.slipreader

import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.thai.ThaiTextRecognizerOptions

class MainActivity : AppCompatActivity() {

    private lateinit var tvResult: TextView
    private lateinit var btnSelectImage: Button

    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { processSlipImage(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }

        btnSelectImage = Button(this).apply {
            text = "เลือกรูปสลิปจากเครื่อง"
            setOnClickListener { pickImageLauncher.launch("image/*") }
        }

        tvResult = TextView(this).apply {
            text = "ผลลัพธ์การสแกนสลิปจะแสดงที่นี่..."
            textSize = 16f
            setPadding(0, 32, 0, 0)
        }

        layout.addView(btnSelectImage)
        layout.addView(tvResult)
        setContentView(layout)
    }

    private fun processSlipImage(imageUri: Uri) {
        try {
            val image = InputImage.fromFilePath(this, imageUri)
            val recognizer = TextRecognition.getClient(ThaiTextRecognizerOptions.Builder().build())

            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    val rawText = visionText.text
                    val parsedData = SlipParser.parse(rawText)

                    tvResult.text = """
                        === ข้อมูลสลิปที่แกะได้ ===
                        💰 ยอดเงิน: ${parsedData.amount ?: "ไม่ระบุ"} บาท
                        📅 วันที่: ${parsedData.date ?: "ไม่ระบุ"}
                        ⏰ เวลา: ${parsedData.time ?: "ไม่ระบุ"}
                        
                        --- ข้อความดิบทั้งหมด ---
                        $rawText
                    """.trimIndent()
                }
                .addOnFailureListener { e ->
                    Toast.makeText(this, "อ่านสลิปไม่สำเร็จ: ${e.message}", Toast.LENGTH_SHORT).show()
                }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
