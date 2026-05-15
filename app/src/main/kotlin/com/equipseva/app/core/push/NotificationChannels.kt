package com.equipseva.app.core.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.content.getSystemService

object NotificationChannels {
    // Channel ids must match the cross-surface push payload contract.
    const val JOBS = "jobs"
    const val CHAT = "chat"
    const val ACCOUNT = "account"

    fun register(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService<NotificationManager>() ?: return
        // "orders" was a marketplace-era channel; the marketplace shipped
        // off in v1. Delete the legacy channel so it stops appearing in
        // the system Notifications settings panel on upgrade installs.
        runCatching { nm.deleteNotificationChannel("orders") }
        nm.createNotificationChannels(
            listOf(
                NotificationChannel(JOBS, "Available jobs", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "New repair jobs and bid responses"
                },
                NotificationChannel(CHAT, "Chat messages", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Direct messages with hospitals and engineers"
                },
                // IMPORTANCE_HIGH so KYC status changes, suspension
                // alerts, and other security-sensitive pushes heads-up
                // rather than landing silently in the tray. Existing
                // installs keep whatever the user has configured —
                // channel importance only ratchets DOWN via app
                // update; raising it post-install requires user opt-in
                // via system settings, which is acceptable for an
                // app-wide bump from DEFAULT → HIGH on a single
                // channel.
                NotificationChannel(ACCOUNT, "Account & security", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Verification, KYC, security alerts"
                },
            ),
        )
    }
}
