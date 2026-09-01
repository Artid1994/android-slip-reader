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
        val folderUri = Uri.parse(folderUriStr)

        val folder = DocumentFile.fromTreeUri(applicationContext, folderUri) ?: return Result.success()
        val files = folder.listFiles()

        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        for (file in files) {
            if (file.isFile && (file.type?.startsWith("image/") == true || file.name?.endsWith(".jpg", ignoreCase = true) == true || file.name?.endsWith(".png", ignoreCase = true) == true)) {
                try {
                    val image = InputImage.fromFilePath(applicationContext, file.uri)
                    val result = Tasks.await(recognizer.process(image))
                    val record = SlipParser.parse(result.text)
                    if (record != null) {
                        repository.saveTransaction(record)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        return Result.success()
    }
}
