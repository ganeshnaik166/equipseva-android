package com.equipseva.app.core.data.account

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseDataExportRepository @Inject constructor(
    private val client: SupabaseClient,
) {

    suspend fun exportToFile(targetDir: File): Result<File> = runCatching {
        val json = withContext(Dispatchers.IO) {
            client.postgrest.rpc(function = "export_my_data").data
        }
        withContext(Dispatchers.IO) {
            if (!targetDir.exists()) targetDir.mkdirs()
            val stamp = DateTimeFormatter
                .ofPattern("yyyyMMdd-HHmmss", Locale.US)
                .withZone(ZoneOffset.UTC)
                .format(Instant.now())
            val file = File(targetDir, "equipseva-export-$stamp.json")
            file.writeText(json)
            file
        }
    }
}
