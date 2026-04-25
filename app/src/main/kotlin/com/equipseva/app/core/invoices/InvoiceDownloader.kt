package com.equipseva.app.core.invoices

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Saves an invoice URL to the device's public Downloads folder via the system
 * [DownloadManager]. Uses [DownloadManager.Request.setDestinationInExternalPublicDir]
 * which on API 29+ writes to MediaStore-managed Downloads — no extra permission
 * needed for the app's own files.
 */
@Singleton
class InvoiceDownloader @Inject constructor(
    @ApplicationContext private val appContext: Context,
) {
    fun download(orderNumberOrId: String, invoiceUrl: String): Long {
        val filename = "EquipSeva_Invoice_${sanitize(orderNumberOrId)}.html"
        val req = DownloadManager.Request(Uri.parse(invoiceUrl))
            .setTitle("EquipSeva invoice")
            .setDescription("Order $orderNumberOrId")
            .setMimeType("text/html")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
        val dm = appContext.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return dm.enqueue(req)
    }

    private fun sanitize(s: String): String =
        s.replace("[^A-Za-z0-9._-]".toRegex(), "_").take(64)
}
