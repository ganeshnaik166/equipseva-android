package com.equipseva.app.navigation

import android.content.Intent
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.receiveAsFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Bridge between [android.app.Activity.onNewIntent] / launch intents and the
 * Compose nav graph. The activity calls [dispatch] on each intent; the main
 * nav graph collects [events] and navigates accordingly.
 *
 * Marketplace `equipseva.com/pay/return` parsing was stripped along with the
 * Razorpay flow in the v1 cleanup. Only push-notification routes (stamped
 * via [EXTRA_ROUTE] by the FCM service) flow through here today.
 */
@Singleton
class DeepLinkRouter @Inject constructor() {

    sealed interface Event {
        /**
         * A pre-resolved route string the nav graph can navigate directly to.
         * Emitted when the activity launch intent carries [EXTRA_ROUTE], which
         * the FCM messaging service stamps after running [NotificationDeepLink].
         */
        data class OpenRoute(val route: String) : Event
    }

    private val channel = Channel<Event>(Channel.BUFFERED)
    val events = channel.receiveAsFlow()

    fun dispatch(intent: Intent?) {
        if (intent == null) return
        eventForRouteExtra(intent.getStringExtra(EXTRA_ROUTE))
            ?.let { channel.trySend(it) }
    }

    companion object {
        const val EXTRA_ROUTE = "com.equipseva.app.deeplink.ROUTE"
    }
}

/**
 * Pure intent-extra → Event mapping, split out so a JVM unit test can
 * pin the null / blank / whitespace rules without spinning up an Android
 * Intent. Returns null when the extra is absent or whitespace-only — in
 * either case the router stays silent rather than navigating to a bogus
 * route. Any non-blank string is forwarded verbatim; the nav graph is
 * the source of truth for route validity, not the router.
 */
internal fun eventForRouteExtra(raw: String?): DeepLinkRouter.Event? {
    val trimmed = raw?.takeIf { it.isNotBlank() } ?: return null
    return DeepLinkRouter.Event.OpenRoute(trimmed)
}
