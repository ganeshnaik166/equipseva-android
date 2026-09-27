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
 * Compose nav graph. Ordinary intents reach only an active host. A first
 * Activity launch may hold one route stamped with the current SDK login ticket
 * until the host observes that same login. Nothing without a ticket is saved.
 *
 * Three external formats are handled, subject to the same route policy:
 *  1. [EXTRA_ROUTE] string extra — stamped by the FCM service after running
 *     NotificationDeepLink. The activity is exported, so this value is
 *     untrusted and must pass [DeepLinkPolicy] before navigation.
 *  2. Raw FCM `kind`/ID extras — placed on launcher intents by Android when a
 *     combined notification+data message arrives while the app is backgrounded.
 *  3. [Intent.getData] HTTPS URI on `equipseva.com` / `www.equipseva.com` — the
 *     App Link path declared with autoVerify=true in the manifest. A small
 *     whitelist of paths maps to nav routes; anything else is ignored so the
 *     app falls back to its default landing screen.
 */
@Singleton
class DeepLinkRouter @Inject constructor(
    private val ticketSource: LoginTicketSource,
) {

    /** Opaque local identity for one Activity instance, never read from an Intent. */
    class LaunchOwner

    sealed interface Event {
        /**
         * A pre-resolved route string the nav graph can navigate directly to.
         * Emitted for admitted EXTRA_ROUTE values, safe inbox fallbacks, and
         * recognized App Link URIs.
         */
        data class OpenRoute(
            val route: String,
            val ticket: LoginTicketSnapshot,
            val launchOwner: LaunchOwner = DEFAULT_OWNER,
        ) : Event
    }

    private class SinkRegistration(val sink: (Event.OpenRoute) -> Unit)
    private data class StartupHandoff(val owner: LaunchOwner, val event: Event.OpenRoute)

    private val sinkLock = Any()
    private val activeOwners = mutableSetOf(DEFAULT_OWNER)
    private val sinks = mutableMapOf<LaunchOwner, SinkRegistration>()
    private var pendingStartup: StartupHandoff? = null

    /** A recreated or second Activity gets a fresh, unforgeable route owner. */
    fun beginActivity(owner: LaunchOwner) = synchronized(sinkLock) {
        activeOwners += owner
        // The newest Activity launch supersedes an older unclaimed tap.
        pendingStartup = null
    }

    /** Activity teardown cannot revoke another Activity's pending launch. */
    fun endActivity(owner: LaunchOwner) = synchronized(sinkLock) {
        activeOwners -= owner
        sinks.remove(owner)
        if (pendingStartup?.owner === owner) pendingStartup = null
    }

    internal fun isOwnerActive(owner: LaunchOwner): Boolean = synchronized(sinkLock) {
        owner in activeOwners
    }

    /** Replaces only this Activity's host; a stale close cannot remove its successor. */
    fun registerSink(
        owner: LaunchOwner = DEFAULT_OWNER,
        sink: (Event.OpenRoute) -> Unit,
    ): AutoCloseable {
        val registration = SinkRegistration(sink)
        synchronized(sinkLock) {
            if (owner in activeOwners) sinks[owner] = registration
        }
        return AutoCloseable {
            synchronized(sinkLock) {
                if (sinks[owner] === registration) sinks.remove(owner)
            }
        }
    }

    /** Ordinary onNewIntent ingress: no host means drop, including any older startup tap. */
    fun dispatch(intent: Intent?, owner: LaunchOwner = DEFAULT_OWNER) =
        dispatchIntent(intent, owner, startup = false)

    /** Called only for a fresh Activity launch, before Compose mounts its main host. */
    fun dispatchStartup(intent: Intent?, owner: LaunchOwner = DEFAULT_OWNER) =
        dispatchIntent(intent, owner, startup = true)

    private fun dispatchIntent(intent: Intent?, owner: LaunchOwner, startup: Boolean) {
        // MainActivity is exported. Android may throw while unparcelling an
        // attacker-supplied Bundle or URI; never let that crash the Activity.
        // Keep the active-host callback outside this catch so app bugs there
        // remain visible rather than being misclassified as bad input.
        val event = try {
            intent?.let { resolveEvent(it, owner) }
        } catch (_: BadParcelableException) {
            null
        } catch (_: ClassCastException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        }
        val registration = synchronized(sinkLock) {
            if (owner !in activeOwners) return@synchronized null
            val matchingSink = sinks[owner]
            if (startup && matchingSink == null) {
                // An old Activity's sink cannot consume this new launch.
                pendingStartup = event?.let { StartupHandoff(owner, it) }
                null
            } else {
                // Only this Activity's newer ordinary intent can retire its
                // own pending tap. Another Activity's ingress leaves it alone.
                if (pendingStartup?.owner === owner) pendingStartup = null
                matchingSink
            }
        }
        if (event != null) registration?.sink(event)
    }

    /** Wrong-Activity claims leave the slot intact; the matching owner consumes once. */
    internal fun takeStartupFor(owner: LaunchOwner, userId: String): Event.OpenRoute? =
        synchronized(sinkLock) {
            val pending = pendingStartup ?: return@synchronized null
            if (pending.owner !== owner || owner !in activeOwners) return@synchronized null
            pendingStartup = null
            pending.event.takeIf {
                it.ticket.userId == userId && ticketSource.currentTicket() == it.ticket
            }
        }

    /**
     * Retire on this Activity's auth boundary, a departing recipient, or an
     * SDK ticket change. A stale A host must not erase a new B Activity's tap
     * while B's exact ticket is still live.
     */
    internal fun retireStartupFor(observer: LaunchOwner?, departedUserId: String?) =
        synchronized(sinkLock) {
            val pending = pendingStartup ?: return@synchronized
            if (pending.owner === observer ||
                pending.event.ticket.userId == departedUserId ||
                ticketSource.currentTicket() != pending.event.ticket
            ) {
                pendingStartup = null
            }
        }

    private fun resolveEvent(intent: Intent, owner: LaunchOwner): Event.OpenRoute? {
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
        return Event.OpenRoute(route, ticket, owner)
    }

    companion object {
        /** Legacy test ingress. Production always supplies its Activity owner. */
        val DEFAULT_OWNER = LaunchOwner()
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
