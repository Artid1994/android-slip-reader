package com.example.slipreader

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class SlipAutoScanWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        val repository = TransactionRepository(applicationContext)
        val folderUriStr = repository.getAutoFolderUri() ?: return Result.success()
        
        try {
            val folderUri = Uri.parse(folderUriStr)
            val folder = DocumentFile.fromTreeUri(applicationContext, folderUri) ?: return Result.success()

            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

            // เรียกฟังก์ชันสแกนแบบวนลึกทุกไฟล์และโฟลเดอร์ย่อย
            scanDocumentFile(folder, recognizer, repository)

        } catch (e: Exception) {
            e.printStackTrace()
            return Result.failure()
        }

        return Result.success()
    }

    private fun scanDocumentFile(
        fileOrFolder: DocumentFile,
        recognizer: com.google.mlkit.vision.text.TextRecognizer,
        repository: TransactionRepository
    ) {
        if (fileOrFolder.isDirectory) {
            for (file in fileOrFolder.listFiles()) {
                scanDocumentFile(file, recognizer, repository)
            }
        } else if (fileOrFolder.isFile) {
            val name = fileOrFolder.name?.lowercase() ?: ""
            val type = fileOrFolder.type?.lowercase() ?: ""

            if (type.startsWith("image/") || name.endsWith(".jpg") || name.endsWith(".png") || name.endsWith(".jpeg")) {
                try {
                    val inputStream = applicationContext.contentResolver.openInputStream(fileOrFolder.uri)
                    if (inputStream != null) {
                        val image = InputImage.fromFilePath(applicationContext, fileOrFolder.uri)
                        val result = Tasks.await(recognizer.process(image))
                        val record = SlipParser.parse(result.text)
                        if (record != null) {
                            repository.saveTransaction(record)
                        }
                        inputStream.close()
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}
