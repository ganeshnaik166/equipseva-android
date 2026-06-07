package com.equipseva.app.core.data.account

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.time.Instant
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
            // Round 459 fix: stamp the export filename in IST so the
            // user opens "equipseva-export-20260608-020000.json" and
            // recognises 2026-06-08 02:00 IST instead of seeing the
            // UTC offset (20:30 prior day) on a file they just
            // generated.
            val stamp = DateTimeFormatter
                .ofPattern("yyyyMMdd-HHmmss", Locale.US)
                .withZone(java.time.ZoneId.of("Asia/Kolkata"))
                .format(Instant.now())
            val file = File(targetDir, "equipseva-export-$stamp.json")
            file.writeText(json)
            file
        }
    }
}
