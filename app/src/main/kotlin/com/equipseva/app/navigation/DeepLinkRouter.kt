package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.receiveAsFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Bridge between [android.app.Activity.onNewIntent] / launch intents and the
 * Compose nav graph. The activity calls [dispatch] on each intent; the main
 * nav graph collects [events] and navigates accordingly.
 *
 * Two entry points handled, in priority order:
 *  1. [EXTRA_ROUTE] string extra — stamped by the FCM service after running
 *     NotificationDeepLink. Wins because the notification payload is the most
 *     specific signal.
 *  2. [Intent.getData] HTTPS URI on `equipseva.com` / `www.equipseva.com` — the
 *     App Link path declared with autoVerify=true in the manifest. A small
 *     whitelist of paths maps to nav routes; anything else is ignored so the
 *     app falls back to its default landing screen.
 */
@Singleton
class DeepLinkRouter @Inject constructor() {

    sealed interface Event {
        /**
         * A pre-resolved route string the nav graph can navigate directly to.
         * Emitted for both EXTRA_ROUTE and recognized App Link URIs.
         */
        data class OpenRoute(val route: String) : Event
    }

    private val channel = Channel<Event>(Channel.BUFFERED)
    val events = channel.receiveAsFlow()

    fun dispatch(intent: Intent?) {
        if (intent == null) return
        val route = intent.getStringExtra(EXTRA_ROUTE)
            ?.takeIf { it.isNotBlank() }
            ?: routeFor(intent.data)
        route?.let { channel.trySend(Event.OpenRoute(it)) }
    }

    companion object {
        const val EXTRA_ROUTE = "com.equipseva.app.deeplink.ROUTE"

        private val APP_LINK_HOSTS = setOf("equipseva.com", "www.equipseva.com")

        /**
         * Maps a launch URI from an App Link tap to a Compose nav route, or
         * null when the path isn't part of the supported set. Falls through
         * to a pure-Kotlin helper so the path logic stays unit-testable
         * without dragging in Robolectric.
         */
        private fun routeFor(uri: Uri?): String? {
            if (uri == null) return null
            return routeForParts(uri.scheme, uri.host, uri.pathSegments.orEmpty())
        }

        // Job ids in deep-links are the human-readable job_number
        // (e.g. RPR-00027), not the underlying UUID. Validate strictly
        // so /job/<garbage> doesn't navigate into a detail screen that
        // will then 404 against Supabase + leave the user stuck on a
        // blank "Couldn't load" state.
        private val JOB_ID_REGEX = Regex("^RPR-\\d{1,8}$", RegexOption.IGNORE_CASE)
        // Conversations + engineer ids are server-generated UUIDs.
        private val UUID_REGEX = Regex(
            "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
            RegexOption.IGNORE_CASE,
        )

        /** Pure helper for [routeFor]. Visible for testing. */
        internal fun routeForParts(
            scheme: String?,
            host: String?,
            segments: List<String>,
        ): String? {
            if (scheme != "https") return null
            if (host !in APP_LINK_HOSTS) return null
            return when {
                segments.size == 2 && segments[0] == "job" && JOB_ID_REGEX.matches(segments[1]) ->
                    Routes.repairJobDetailRoute(segments[1])
                segments.size == 2 && segments[0] == "chat" && UUID_REGEX.matches(segments[1]) ->
                    Routes.chatRoute(segments[1])
                segments.size == 2 && segments[0] == "engineer" && UUID_REGEX.matches(segments[1]) ->
                    Routes.engineerPublicProfileRoute(segments[1])
                segments.size == 1 && segments[0] == "engineers" -> Routes.ENGINEER_DIRECTORY
                segments.size == 1 && segments[0] == "notifications" -> Routes.NOTIFICATIONS
                else -> null
            }
        }
    }
}
