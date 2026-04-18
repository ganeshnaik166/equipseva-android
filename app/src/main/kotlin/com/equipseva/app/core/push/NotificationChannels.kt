package com.equipseva.app.core.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.content.getSystemService

object NotificationChannels {
    // Channel ids must match the cross-surface push payload contract.
    const val ORDERS = "orders"
    const val JOBS = "jobs"
    const val CHAT = "chat"
    const val ACCOUNT = "account"

    fun register(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService<NotificationManager>() ?: return
        nm.createNotificationChannels(
            listOf(
                NotificationChannel(ORDERS, "Order updates", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Order status, delivery, returns"
                },
                NotificationChannel(JOBS, "Available jobs", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "New repair jobs and bid responses"
                },
                NotificationChannel(CHAT, "Chat messages", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Direct messages with hospitals and engineers"
                },
                NotificationChannel(ACCOUNT, "Account & security", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Verification, KYC, security alerts"
                },
            ),
        )
    }
}
