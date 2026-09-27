package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import android.os.BadParcelableException
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Bridge between [android.app.Activity.onNewIntent] / launch intents and the
 * Compose nav graph. The activity calls [dispatch] on each intent; an active
 * host receives the route synchronously with the current SDK login ticket.
 * With no host or no authenticated ticket, ingress is discarded rather than
 * replayed to a future account.
 *
 * Two entry points handled, in priority order:
 *  1. [EXTRA_ROUTE] string extra — stamped by the FCM service after running
 *     NotificationDeepLink. The activity is exported, so this value is
 *     untrusted and must pass [DeepLinkPolicy] before navigation.
 *  2. [Intent.getData] HTTPS URI on `equipseva.com` / `www.equipseva.com` — the
 *     App Link path declared with autoVerify=true in the manifest. A small
 *     whitelist of paths maps to nav routes; anything else is ignored so the
 *     app falls back to its default landing screen.
 */
@Singleton
class DeepLinkRouter @Inject constructor(
    private val ticketSource: LoginTicketSource,
) {

    sealed interface Event {
        /**
         * A pre-resolved route string the nav graph can navigate directly to.
         * Emitted for admitted EXTRA_ROUTE values, safe inbox fallbacks, and
         * recognized App Link URIs.
         */
        data class OpenRoute(
            val route: String,
            val ticket: LoginTicketSnapshot,
        ) : Event
    }

    private class SinkRegistration(val sink: (Event.OpenRoute) -> Unit)

    private val sinkLock = Any()
    private var activeSink: SinkRegistration? = null

    /**
     * Replaces the current host. Closing a superseded registration cannot
     * unregister the replacement.
     */
    fun registerSink(sink: (Event.OpenRoute) -> Unit): AutoCloseable {
        val registration = SinkRegistration(sink)
        synchronized(sinkLock) { activeSink = registration }
        return AutoCloseable {
            synchronized(sinkLock) {
                if (activeSink === registration) activeSink = null
            }
        }
    }

    fun dispatch(intent: Intent?) {
        if (intent == null) return
        // MainActivity is exported. Android may throw while unparcelling an
        // attacker-supplied Bundle or URI; never let that crash the Activity.
        // Keep the active-host callback outside this catch so app bugs there
        // remain visible rather than being misclassified as bad input.
        val event = try {
            resolveEvent(intent)
        } catch (_: BadParcelableException) {
            return
        } catch (_: ClassCastException) {
            return
        } catch (_: IllegalArgumentException) {
            return
        } ?: return
        synchronized(sinkLock) {
            activeSink?.sink?.invoke(event)
        }
    }

    private fun resolveEvent(intent: Intent): Event.OpenRoute? {
        val hasCustomRoute = intent.hasExtra(EXTRA_ROUTE)
        // FCM notification+data messages received in the background bypass
        // FirebaseMessagingService. Android puts these server data keys on
        // MainActivity's launcher Intent instead of our custom route extra.
        val hasRawPush = intent.hasExtra("notification_id") || intent.hasExtra("kind")
        val externalRoute = if (hasCustomRoute) intent.getStringExtra(EXTRA_ROUTE) else null
        val appLinkRoute = routeFor(intent.data)
        // A mixed custom/raw Intent is ambiguous and can be forged. Ignore
        // both push selectors; an independent, valid HTTPS App Link may stand.
        val mixedPushSources = hasCustomRoute && hasRawPush
        val rawRoute = if (hasRawPush && !mixedPushSources) {
            val kind = intent.getStringExtra("kind")
            val selectors = buildMap {
                RAW_PUSH_ID_KEYS.forEach { key ->
                    intent.getStringExtra(key)?.let { put(key, it) }
                }
            }
            NotificationDeepLink.routeFor(kind, selectors)
        } else null
        val customDirect = externalRoute?.takeIf(DeepLinkPolicy::allows)
        val rawDirect = rawRoute?.takeIf(DeepLinkPolicy::allows)
        val inboxFallback = when {
            mixedPushSources -> null
            hasCustomRoute -> DeepLinkPolicy.inboxFallback(externalRoute)
            hasRawPush -> DeepLinkPolicy.inboxFallback(rawRoute) ?: Routes.NOTIFICATIONS
            else -> null
        }
        if (customDirect == null && rawDirect == null && appLinkRoute == null && inboxFallback == null) {
            return null
        }
        val ticket = ticketSource.currentTicket() ?: return null
        // A push captured for account A must not inherit account B's live
        // ticket at tap time. The extra is forgeable on this exported Activity;
        // it filters stale notifications, while the allow-list and server RLS
        // remain the actual route/data authorization boundaries. App Links do
        // not have a push recipient and are evaluated independently.
        val recipient = when {
            mixedPushSources -> null
            hasCustomRoute -> intent.getStringExtra(EXTRA_RECIPIENT_USER_ID)
            hasRawPush -> intent.getStringExtra("user_id")
            else -> null
        }
        val matchesPushRecipient = recipient != null && recipient == ticket.userId
        val route = when {
            mixedPushSources -> appLinkRoute ?: return null
            customDirect != null && matchesPushRecipient -> customDirect
            appLinkRoute != null -> appLinkRoute
            rawDirect != null && matchesPushRecipient -> rawDirect
            inboxFallback != null && matchesPushRecipient -> inboxFallback
            else -> return null
        }
        if (!DeepLinkPolicy.allows(route)) return null
        return Event.OpenRoute(route, ticket)
    }

    companion object {
        const val EXTRA_ROUTE = "com.equipseva.app.deeplink.ROUTE"
        // A local stale-tray filter only. MainActivity is exported, so this
        // caller-supplied value never proves push origin or server access.
        const val EXTRA_RECIPIENT_USER_ID = "com.equipseva.app.deeplink.RECIPIENT_USER_ID"

        // Read only selectors used by the pure mapper. In particular, never
        // interpret arbitrary raw deep_link/route strings from exported extras.
        private val RAW_PUSH_ID_KEYS = listOf(
            "conversation_id", "repair_job_id", "engineer_id", "amc_contract_id",
        )

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
