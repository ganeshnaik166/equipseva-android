package com.equipseva.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import com.equipseva.app.navigation.DeepLinkRouter

/**
 * Distinguishes a newly delivered external launch from the old Intent Android
 * can restore with an Activity's saved state. This only decides whether to ask
 * DeepLinkRouter to inspect a launch; it does not establish its origin, login
 * owner, route permission, or server access.
 */
internal object RestoredTaskIngress {
    private const val STATE_DELIVERY = "com.equipseva.app.restored_task_delivery"
    private const val LAUNCHER = "launcher"
    private const val NOTIFICATION = "notification:"
    private const val RAW_PUSH = "raw_push:"
    private const val APP_LINK = "app_link:"
    private const val INTERNAL_NOTIFICATION_SCHEME = "equipseva-internal-notification"
    private val uuid = Regex(
        "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
        RegexOption.IGNORE_CASE,
    )

    /**
     * A restored Intent can already have been handled after the last state
     * save, even when its delivery ID differs from the saved marker. Its ID
     * cannot prove freshness after process death. New taps delivered to a
     * living Activity use onNewIntent directly; an exact in-process pending
     * push can instead transfer through the router's retained opaque owner.
     */
    fun shouldDispatch(savedState: Bundle?, @Suppress("UNUSED_PARAMETER") intent: Intent?): Boolean =
        savedState == null

    /** Save only a bounded identity, never an Intent, credential, or push payload. */
    fun record(outState: Bundle, intent: Intent?) {
        val identity = deliveryIdentity(intent)
        if (identity == null) outState.remove(STATE_DELIVERY)
        else outState.putString(STATE_DELIVERY, identity)
    }

    /** Only a unique push delivery may cross an in-process Activity recreation. */
    fun uniqueSavedDeliveryIdentity(savedState: Bundle?): String? {
        val identity = try {
            savedState?.getString(STATE_DELIVERY)
        } catch (_: RuntimeException) {
            null
        }
        return identity?.takeIf(::isUniquePushIdentity)
    }

    /** Called at both ingress and transfer; never treats a route as a delivery ID. */
    fun uniquePushIdentity(intent: Intent?): String? =
        deliveryIdentity(intent)?.takeIf(::isUniquePushIdentity)

    fun matchesUniquePushIdentity(savedIdentity: String?, intent: Intent?): Boolean =
        savedIdentity != null && isUniquePushIdentity(savedIdentity) &&
            uniquePushIdentity(intent) == savedIdentity

    private fun isUniquePushIdentity(identity: String): Boolean =
        identity.length <= 128 && (
            (identity.startsWith(NOTIFICATION) &&
                uuid.matches(identity.removePrefix(NOTIFICATION))) ||
            (identity.startsWith(RAW_PUSH) &&
                uuid.matches(identity.removePrefix(RAW_PUSH)))
            )

    private fun deliveryIdentity(intent: Intent?): String? {
        if (intent == null) return null
        // Android may throw when unparcelling a hostile exported Intent. Only
        // its primitive delivery selectors are read here, and any bad value
        // makes a restored launch ineligible for dispatch.
        return try {
            val data = intent.data
            if (data != null) {
                val notificationId = internalNotificationId(data)
                if (notificationId != null) return NOTIFICATION + notificationId
                if (intent.action == Intent.ACTION_VIEW) {
                    val route = DeepLinkRouter.routeForParts(
                        data.scheme,
                        data.host,
                        data.pathSegments.orEmpty(),
                    )
                    if (route != null) return APP_LINK + route
                }
                return null
            }

            if (intent.hasExtra("notification_id") || intent.hasExtra("kind")) {
                // The sender always includes its validated notification UUID,
                // including for unknown kinds whose `kind` is omitted. A raw
                // tap without that ID has no stable restored-task identity.
                val id = intent.getStringExtra("notification_id") ?: return null
                return if (uuid.matches(id)) RAW_PUSH + id.lowercase() else null
            }
            if (intent.action == Intent.ACTION_MAIN) LAUNCHER else null
        } catch (_: RuntimeException) {
            null
        }
    }

    private fun internalNotificationId(uri: Uri): String? {
        if (uri.scheme != INTERNAL_NOTIFICATION_SCHEME || uri.host != "tap") return null
        if (uri.query != null || uri.fragment != null) return null
        val id = uri.pathSegments.singleOrNull() ?: return null
        if (!uuid.matches(id)) return null
        return id.lowercase()
    }

}
