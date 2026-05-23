package com.equipseva.app.core.push

import android.Manifest
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
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
        val channel = resolvePushChannel(data["channel"])
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
        val (title, body) = resolvePushTitleAndBody(
            rawTitle = rawTitle,
            rawBody = rawBody,
            fallbackTitle = getString(R.string.app_name),
        ) ?: return

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

        // Category hint for DND / priority filtering — without it,
        // Do-Not-Disturb rules can silently suppress posts that the
        // user has explicitly allowed by category (e.g. CATEGORY_MESSAGE
        // is in most DND allow-lists by default).
        val notifCategory = notificationCategoryFor(channel)
        val notification = NotificationCompat.Builder(this, channel)
            // Round 450 — ic_notification (white-on-transparent vector). The
            // previous mipmap.ic_launcher was the colored adaptive launcher
            // icon, which renders as a blank/garbled square in the status
            // bar on Lollipop+ per the platform's "white only" rule.
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setCategory(notifCategory)
            .setContentIntent(pendingIntent)
            .build()

        val notifyId = resolveNotifyId(data["kind"], data, message.messageId)
        // POST_NOTIFICATIONS is a runtime permission on Android 13+
        // (TIRAMISU). When the user denies it, NotificationManager.notify
        // silently drops the post — but a SecurityException has been
        // observed on some OEMs in field crash reports when the check
        // is missing. Guard explicitly so the intent is recorded and
        // we no-op gracefully instead of risking the surprise throw.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        getSystemService<NotificationManager>()?.notify(notifyId, notification)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

}

// Caps for push notification title/body lengths. Defends against
// malformed server payloads — the full string rides in the Bundle
// attached to the PendingIntent and a 100KB title can push the Bundle
// past the 1MB IPC ceiling and crash on notify(). Conservative: real
// titles fit in 80 chars and real bodies in 240.
internal const val PUSH_TITLE_MAX_CHARS = 200
internal const val PUSH_BODY_MAX_CHARS = 1000

/**
 * Resolves a push notification's [NotificationCompat] category from the
 * resolved [channel]. The category hint matters for Do-Not-Disturb
 * filtering — CATEGORY_MESSAGE is in most DND allow-lists by default,
 * so chat pushes survive DND. Unknown channels fall through to
 * CATEGORY_RECOMMENDATION so the cap fires no matter what
 * [resolvePushChannel] folded an unrecognised value to.
 */
internal fun notificationCategoryFor(channel: String): String = when (channel) {
    NotificationChannels.CHAT -> NotificationCompat.CATEGORY_MESSAGE
    NotificationChannels.JOBS -> NotificationCompat.CATEGORY_SOCIAL
    NotificationChannels.ACCOUNT -> NotificationCompat.CATEGORY_STATUS
    else -> NotificationCompat.CATEGORY_RECOMMENDATION
}

/**
 * Resolves the final title + body shown in the system notification, or
 * null when both raw values are empty (drop the push — bare app name
 * with an empty subtitle is useless to the user). Each side is capped
 * at the configured max so a malformed server payload can't push the
 * IPC Bundle past 1MB.
 *
 * Pinned semantics:
 *   * Both null/blank → return null (caller drops the push).
 *   * Title null → use [fallbackTitle] (app name).
 *   * Title blank-but-non-null → keep the blank (don't fall back).
 *     A blank title with a body still posts; the system fills in app
 *     name automatically via the channel.
 *   * Body null → empty string (notify accepts an empty contentText).
 *   * Caps applied AFTER fallback so the fallback itself can be
 *     longer than [maxTitleChars] without surprising the test.
 */
internal fun resolvePushTitleAndBody(
    rawTitle: String?,
    rawBody: String?,
    fallbackTitle: String,
    maxTitleChars: Int = PUSH_TITLE_MAX_CHARS,
    maxBodyChars: Int = PUSH_BODY_MAX_CHARS,
): Pair<String, String>? {
    if (rawTitle.isNullOrBlank() && rawBody.isNullOrBlank()) return null
    val title = (rawTitle ?: fallbackTitle).take(maxTitleChars)
    val body = rawBody.orEmpty().take(maxBodyChars)
    return title to body
}

/**
 * Resolves an incoming push payload's `channel` to one of the three
 * registered [NotificationChannels] ids. Empty-string and unknown
 * channels fold to ACCOUNT so a malformed server send still surfaces
 * to the user instead of vanishing (NotificationCompat silently drops
 * posts with a blank/unknown channel on API 26+).
 */
internal fun resolvePushChannel(rawChannel: String?): String {
    val nonBlank = rawChannel?.takeIf { it.isNotBlank() }
    return when (nonBlank) {
        NotificationChannels.JOBS,
        NotificationChannels.CHAT,
        NotificationChannels.ACCOUNT -> nonBlank
        else -> NotificationChannels.ACCOUNT
    }
}

/**
 * Resolves the per-message notify-id used to post the system
 * notification. Chat pushes collapse per `conversationId` so a
 * second message in the same thread replaces the previous post
 * instead of stacking; all other kinds use the FCM messageId so
 * each push surfaces independently.
 *
 * Accepts both wire shapes for the conversation id: snake_case
 * (`conversation_id`, post-PR #200) and camelCase (`conversationId`,
 * legacy). Pin so a server-side rename doesn't silently lose the
 * collapse behaviour.
 */
internal fun resolveNotifyId(
    kind: String?,
    data: Map<String, String>,
    messageId: String?,
): Int {
    val convoId = data["conversationId"] ?: data["conversation_id"]
    return if (kind == "chat_message" && convoId != null) {
        ("chat:$convoId").hashCode()
    } else {
        messageId.hashCode()
    }
}
