package com.equipseva.app.core.data.account

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseDataExportRepository @Inject constructor(
    private val client: SupabaseClient,
) : DataExportRepository {

    override suspend fun exportToFile(targetDir: File): Result<File> = runCatching {
        val json = withContext(Dispatchers.IO) {
            client.postgrest.rpc(function = "export_my_data").data
        }
        withContext(Dispatchers.IO) {
            if (!targetDir.exists()) targetDir.mkdirs()
            val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.format(Date())
            val file = File(targetDir, "equipseva-export-$stamp.json")
            file.writeText(json)
            file
        }
    }
}
