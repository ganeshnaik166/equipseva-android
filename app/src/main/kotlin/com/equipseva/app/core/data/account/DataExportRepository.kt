package com.equipseva.app.core.data.account

import java.io.File

interface DataExportRepository {
    suspend fun exportToFile(targetDir: File): Result<File>
}
