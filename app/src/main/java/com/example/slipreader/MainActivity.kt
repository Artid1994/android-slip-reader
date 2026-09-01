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

    // Launcher สำหรับเปิด Gallery เลือกรูปภาพ
    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { processSlipImage(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // สร้าง UI แบบ Simple โปรแกรมมิ่งโดยไม่ต้องใช้ XML Layout
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

    // ฟังก์ชันประมวลผลข้อความจากสลิปด้วย ML Kit ภาษาไทย
    private fun processSlipImage(imageUri: Uri) {
        try {
            val image = InputImage.fromFilePath(this, imageUri)
            val recognizer = TextRecognition.getClient(ThaiTextRecognizerOptions.Builder().build())

            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    val rawText = visionText.text
                    tvResult.text = "ข้อความที่พบในสลิป:\n\n$rawText"
                    
                    // TODO: ส่งข้อความไปผ่าน Regex เพื่อดึง ยอดเงิน วันที่ และประเภทธุรกรรม
                }
                .addOnFailureListener { e ->
                    Toast.makeText(this, "อ่านสลิปไม่สำเร็จ: ${e.message}", Toast.LENGTH_SHORT).show()
                }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
