package com.equipseva.app.core.push

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import com.equipseva.app.MainActivity
import com.equipseva.app.R
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.util.QuietHours
import com.equipseva.app.navigation.DeepLinkRouter
import com.equipseva.app.navigation.NotificationDeepLink
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.time.LocalTime
import javax.inject.Inject

@AndroidEntryPoint
class EquipSevaMessagingService : FirebaseMessagingService() {

    @Inject lateinit var registrar: DeviceTokenRegistrar
    @Inject lateinit var userPrefs: UserPrefs

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNewToken(token: String) {
        scope.launch { registrar.register(token) }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        // Empty-string payloads (`data["channel"] = ""`) used to slip past
        // the Elvis fallback and reach NotificationCompat.Builder, where
        // Android silently drops the notification on API 26+. Treat empty
        // OR unknown channel ids as ACCOUNT so a malformed server send
        // still surfaces to the user instead of vanishing.
        val rawChannel = data["channel"]?.takeIf { it.isNotBlank() }
        val channel = when (rawChannel) {
            NotificationChannels.JOBS,
            NotificationChannels.CHAT,
            NotificationChannels.ACCOUNT -> rawChannel
            else -> NotificationChannels.ACCOUNT
        }
        val category = data["category"]?.takeIf { it.isNotBlank() } ?: channel

        // Client-side per-category mute. Server-side send rules are a separate
        // pending item; for now we honour the user's Settings choice by dropping
        // the visible notification. Any data-only side effects (WorkManager
        // enqueues triggered elsewhere) still run because we return before the
        // NotificationManager.notify call only.
        //
        // `runBlocking` here is safe: onMessageReceived runs on FCM's worker
        // pool, not the main thread — see Firebase docs. We block to keep
        // ordering relative to the synchronous notification post below.
        val muted = runBlocking { userPrefs.observeMutedPushCategories().first() }
        if (category in muted || channel in muted) return

        // Quiet-hours / DND. Cheap per-category check runs first; only hit
        // DataStore again for the time window if the message survived that.
        val quietHours = runBlocking { userPrefs.observeQuietHours().first() }
        if (quietHours.enabled) {
            val now = LocalTime.now()
            val nowMin = now.hour * 60 + now.minute
            if (QuietHours.isWithinWindow(nowMin, quietHours.startMinutes, quietHours.endMinutes)) {
                return
            }
        }

        // When the server sent neither a notification body nor a data
        // title/body the only thing left to render is the bare app name
        // with an empty subtitle — useless to the user. Drop the push.
        val rawTitle = message.notification?.title ?: data["title"]
        val rawBody = message.notification?.body ?: data["body"]
        if (rawTitle.isNullOrBlank() && rawBody.isNullOrBlank()) return
        val title = rawTitle ?: getString(R.string.app_name)
        val body = rawBody.orEmpty()

        // Resolve a deep-link route from the (kind, data) tuple the server
        // attached. Unknown / missing kinds fall through to MainActivity's
        // default landing — the user will see the inbox via normal app flow.
        val route = NotificationDeepLink.routeFor(data["kind"], data)
        val launchIntent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .apply {
                if (route != null) putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
            }
        val pendingIntent = PendingIntent.getActivity(
            this,
            // Distinct request codes per message keep extras from being
            // collapsed by FLAG_UPDATE_CURRENT across simultaneous pushes.
            message.messageId.hashCode(),
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(this, channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        // Stable notify id per (kind, conversationId) for chat pushes so
        // a second message in the same thread replaces the previous push
        // instead of stacking. Falls back to messageId.hashCode for any
        // non-chat kind so existing collapse behaviour is unchanged.
        val convoId = data["conversationId"] ?: data["conversation_id"]
        val notifyId = if (data["kind"] == "chat_message" && convoId != null) {
            ("chat:$convoId").hashCode()
        } else {
            message.messageId.hashCode()
        }
        getSystemService<NotificationManager>()?.notify(notifyId, notification)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
