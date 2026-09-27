package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import android.os.BadParcelableException
import com.equipseva.app.RestoredTaskIngress
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Bridge between [android.app.Activity.onNewIntent] / launch intents and the
 * Compose nav graph. Ordinary intents reach only an active host. A first
 * Activity launch may hold one route stamped with the current SDK login ticket
 * until the host observes that same login. During SDK storage restoration, an
 * ingress-only encrypted-session witness may hold one route; navigation still
 * requires an exact authenticated SDK ticket. Nothing without either ticket is saved.
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
            /** Persisted witness at ingress; never sufficient for navigation. */
            val restoring: Boolean = false,
            /** Monotonic local delivery order; never read from an Intent. */
            internal val ingress: Long = 0L,
            /** A bounded, unique push identity for configuration-only transfer. */
            internal val deliveryIdentity: String? = null,
        ) : Event {
            // Payload equality predates ingress/transfer metadata. Ownership
            // checks read those fields explicitly, never via event equality.
            override fun equals(other: Any?): Boolean = this === other ||
                (other is OpenRoute && route == other.route && ticket == other.ticket &&
                    launchOwner == other.launchOwner && restoring == other.restoring)

            override fun hashCode(): Int {
                var result = route.hashCode()
                result = 31 * result + ticket.hashCode()
                result = 31 * result + launchOwner.hashCode()
                result = 31 * result + restoring.hashCode()
                return result
            }
        }
    }

    private class SinkRegistration(val sink: (Event.OpenRoute) -> Boolean)
    private data class StartupHandoff(val owner: LaunchOwner, val event: Event.OpenRoute)
    private data class TicketWitness(val ticket: LoginTicketSnapshot, val restoring: Boolean)
    private data class Delivery(
        val registration: SinkRegistration,
        val event: Event.OpenRoute,
        val ingress: Long,
    )

    private val sinkLock = Any()
    private val activeOwners = mutableSetOf(DEFAULT_OWNER)
    private val sinks = mutableMapOf<LaunchOwner, SinkRegistration>()
    private val latestIngress = mutableMapOf<LaunchOwner, Long>()
    private var nextIngress = 0L
    private var pendingStartup: StartupHandoff? = null

    /** A recreated or second Activity gets a fresh, unforgeable route owner. */
    fun beginActivity(owner: LaunchOwner) = synchronized(sinkLock) {
        activeOwners += owner
        latestIngress.remove(owner)
        ++nextIngress
        // The newest Activity launch supersedes an older unclaimed tap.
        pendingStartup = null
    }

    /** Activity teardown cannot revoke another Activity's pending launch. */
    fun endActivity(owner: LaunchOwner) = synchronized(sinkLock) {
        activeOwners -= owner
        sinks.remove(owner)
        latestIngress.remove(owner)
        if (pendingStartup?.owner === owner) pendingStartup = null
    }

    /**
     * The old Activity is gone before its configuration replacement starts.
     * Revoke its delivery authority, but leave its exact pending handoff for
     * one in-process transfer. A normal teardown always calls [endActivity].
     */
    internal fun endActivityForRecreation(owner: LaunchOwner) = synchronized(sinkLock) {
        activeOwners -= owner
        sinks.remove(owner)
        if (pendingStartup?.owner !== owner) latestIngress.remove(owner)
    }

    /**
     * Start a new Activity and atomically transfer at most one exact pending
     * notification. The opaque old owner exists only in process, never in a
     * Bundle. A changed ticket, route-only App Link or process death drops it.
     */
    internal fun transferPendingToRestoredActivity(
        previousOwner: LaunchOwner?,
        newOwner: LaunchOwner,
        savedDeliveryIdentity: String?,
        currentIntent: Intent?,
    ): Boolean = synchronized(sinkLock) {
        val pending = pendingStartup
        val witness = readTicketWitness()
        val eligible = previousOwner != null && previousOwner !== newOwner &&
            pending != null && pending.owner === previousOwner &&
            pending.event.ingress != 0L &&
            latestIngress[previousOwner] == pending.event.ingress &&
            witness?.ticket == pending.event.ticket &&
            pending.event.deliveryIdentity == savedDeliveryIdentity &&
            RestoredTaskIngress.matchesUniquePushIdentity(savedDeliveryIdentity, currentIntent)
        // beginActivity's supersession happens regardless of transfer outcome.
        activeOwners += newOwner
        latestIngress.remove(newOwner)
        val transferIngress = ++nextIngress
        pendingStartup = null
        if (eligible) {
            activeOwners -= previousOwner
            sinks.remove(previousOwner)
            latestIngress.remove(previousOwner)
            latestIngress[newOwner] = transferIngress
            pendingStartup = StartupHandoff(
                newOwner,
                pending.event.copy(
                    launchOwner = newOwner,
                    ingress = transferIngress,
                    restoring = witness.restoring,
                ),
            )
        }
        eligible
    }

    internal fun isOwnerActive(owner: LaunchOwner): Boolean = synchronized(sinkLock) {
        owner in activeOwners
    }

    /** Replaces only this Activity's host; a stale close cannot remove its successor. */
    fun registerSink(
        owner: LaunchOwner = DEFAULT_OWNER,
        sink: (Event.OpenRoute) -> Unit,
    ): AutoCloseable = registerAcknowledgingSink(owner) { event ->
        sink(event)
        true
    }

    /** The host acknowledges only after its verified event entered the channel. */
    internal fun registerAcknowledgingSink(
        owner: LaunchOwner,
        sink: (Event.OpenRoute) -> Boolean,
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

    /** Ordinary onNewIntent ingress: only an exact restoring witness may wait without a host. */
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
            resolveAppLinkOnly(intent, owner)
        } catch (_: ClassCastException) {
            resolveAppLinkOnly(intent, owner)
        } catch (_: IllegalArgumentException) {
            resolveAppLinkOnly(intent, owner)
        }
        val deliveryIdentity = RestoredTaskIngress.uniquePushIdentity(intent)
        val delivery = synchronized(sinkLock) {
            if (owner !in activeOwners) return@synchronized null
            val ingress = ++nextIngress
            latestIngress[owner] = ingress
            val ownedEvent = event?.copy(ingress = ingress, deliveryIdentity = deliveryIdentity)
            val matchingSink = sinks[owner]
            if ((startup && matchingSink == null) || ownedEvent?.restoring == true) {
                // An old Activity's sink cannot consume this new launch.
                // A mounted host cannot authenticate a persisted witness until
                // the SDK finishes restoring the exact same login ticket. An
                // ordinary tap during that interval is also owned, even if
                // the main graph has temporarily unmounted its sink.
                pendingStartup = ownedEvent?.let { StartupHandoff(owner, it) }
                null
            } else {
                // Only this Activity's newer ordinary intent can retire its
                // own pending tap. Another Activity's ingress leaves it alone.
                if (pendingStartup?.owner === owner) pendingStartup = null
                if (ownedEvent != null && matchingSink != null) Delivery(matchingSink, ownedEvent, ingress)
                else null
            }
        }
        if (delivery != null && !delivery.registration.sink(delivery.event)) {
            synchronized(sinkLock) {
                // The sink can reject when SDK restoration begins after the
                // first ticket read. Never let an older rejected callback
                // overwrite a newer tap or another Activity's handoff.
                if (owner !in activeOwners ||
                    sinks[owner] !== delivery.registration ||
                    latestIngress[owner] != delivery.ingress ||
                    nextIngress != delivery.ingress
                ) return@synchronized
                val witness = readTicketWitness()
                if (witness?.ticket == delivery.event.ticket) {
                    pendingStartup = StartupHandoff(
                        owner,
                        delivery.event.copy(restoring = witness.restoring),
                    )
                }
            }
        }
    }

    /** Wrong-Activity claims leave the slot intact; the matching owner consumes once. */
    internal fun takeStartupFor(owner: LaunchOwner, userId: String): Event.OpenRoute? =
        synchronized(sinkLock) {
            val pending = pendingStartup ?: return@synchronized null
            if (pending.owner !== owner || owner !in activeOwners) return@synchronized null
            val witness = readTicketWitness()
            if (pending.event.restoring && witness?.restoring == true &&
                witness.ticket == pending.event.ticket
            ) {
                // An observed user ID alone cannot release a persisted tap.
                // Keep it for the eventual SDK-authenticated emission.
                return@synchronized null
            }
            pendingStartup = null
            pending.event.takeIf {
                it.ticket.userId == userId && witness?.restoring == false &&
                    witness.ticket == it.ticket
            }
        }

    /** A production host acknowledges a claim; a same-ticket SDK pause restores its handoff. */
    internal fun deliverStartupFor(
        owner: LaunchOwner,
        userId: String,
        sink: (Event.OpenRoute) -> Boolean,
    ): Boolean {
        val claimed = takeStartupFor(owner, userId) ?: return false
        if (sink(claimed)) return true
        retainIfLatest(claimed, requireRestoring = false)
        return false
    }

    /** Re-offer a queued event only during this exact login's SDK restoration interval. */
    internal fun deferVerifiedDuringRestoration(event: Event.OpenRoute): Boolean =
        retainIfLatest(event, requireRestoring = true)

    /** A host whose auth presentation is Unknown may hold, never emit, its last exact login. */
    internal fun deferVerifiedForCurrentTicket(event: Event.OpenRoute): Boolean =
        retainIfLatest(event, requireRestoring = false)

    private fun retainIfLatest(event: Event.OpenRoute, requireRestoring: Boolean): Boolean =
        synchronized(sinkLock) {
            val owner = event.launchOwner
            if (owner !in activeOwners || event.ingress == 0L ||
                latestIngress[owner] != event.ingress || nextIngress != event.ingress
            ) return@synchronized false
            val witness = readTicketWitness() ?: return@synchronized false
            if (witness.ticket != event.ticket ||
                (requireRestoring && !witness.restoring)
            ) return@synchronized false
            pendingStartup = StartupHandoff(owner, event.copy(restoring = witness.restoring))
            true
        }

    /**
     * MainActivity observes terminal SDK auth status even when no main graph
     * or DeepLinkHost exists. A delayed callback must not erase a newer tap
     * once the SDK again shows an authenticated or restoring login.
     */
    internal fun retireStartupForTerminalSession(owner: LaunchOwner) = synchronized(sinkLock) {
        if (pendingStartup?.owner === owner && readTicketWitness() == null) {
            pendingStartup = null
        }
    }

    /**
     * The root Activity observes auth even when role/onboarding has no host.
     * A delayed callback is ignored unless it names the SDK's current user;
     * an exact new login ticket (including same-UID relogin) retires the tap.
     */
    internal fun observeAuthenticatedSession(owner: LaunchOwner, observedUserId: String) =
        synchronized(sinkLock) {
            val pending = pendingStartup ?: return@synchronized
            if (pending.owner !== owner || owner !in activeOwners ||
                observedUserId.isBlank()
            ) return@synchronized
            val witness = readTicketWitness()
            if (witness?.restoring == false &&
                witness.ticket.userId == observedUserId &&
                witness.ticket != pending.event.ticket
            ) {
                pendingStartup = null
            }
        }

    /**
     * Retire on this Activity's auth boundary, a departing recipient, or an
     * SDK ticket change. A stale A host must not erase a new B Activity's tap
     * while B's exact ticket is still live.
     */
    internal fun retireStartupFor(
        observer: LaunchOwner?,
        departedUserId: String?,
        preserveInitializingRestoration: Boolean = false,
    ) =
        synchronized(sinkLock) {
            val pending = pendingStartup ?: return@synchronized
            val witness = readTicketWitness()
            if (preserveInitializingRestoration && pending.event.restoring &&
                witness?.ticket == pending.event.ticket
            ) {
                // The host's delayed Unknown describes the same Initializing
                // interval in which this tap was captured, not a new login.
                return@synchronized
            }
            if (observer != null &&
                witness?.ticket == pending.event.ticket
            ) {
                // A delayed sign-out for an older session of the same user
                // must not erase this newer exact ticket. A real terminal
                // SDK state has no witness and retires the handoff below.
                return@synchronized
            }
            val sdkTicket = witness?.takeUnless { it.restoring }?.ticket
            val lostTicketWitness = witness?.ticket != pending.event.ticket
            val observedOwnerBoundary = pending.owner === observer &&
                (departedUserId == null || pending.event.ticket.userId == departedUserId)
            // A departing old Activity cannot infer that a different Activity's
            // pending tap is stale merely because the SDK is Initializing.
            // On one Activity, A's delayed sign-out or direct replacement also
            // cannot erase an exact B tap captured for the next login.
            // A concrete different ticket or loss of the exact stored witness
            // does prove that this handoff cannot be claimed safely.
            if (observedOwnerBoundary ||
                pending.event.ticket.userId == departedUserId ||
                (sdkTicket != null && sdkTicket != pending.event.ticket) ||
                lostTicketWitness ||
                (observer == null && departedUserId == null && sdkTicket == null)
            ) {
                pendingStartup = null
            }
        }

    /** Bad push extras contribute nothing; a valid HTTPS App Link stands alone. */
    private fun resolveAppLinkOnly(intent: Intent?, owner: LaunchOwner): Event.OpenRoute? {
        val route = try {
            routeFor(intent?.data)?.takeIf(DeepLinkPolicy::allows)
        } catch (_: BadParcelableException) {
            null
        } catch (_: ClassCastException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        } ?: return null
        val witness = readTicketWitness() ?: return null
        return Event.OpenRoute(route, witness.ticket, owner, restoring = witness.restoring)
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
        val witness = readTicketWitness() ?: return null
        val ticket = witness.ticket
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
        return Event.OpenRoute(route, ticket, owner, restoring = witness.restoring)
    }

    /**
     * The SDK can finish restoration while encrypted storage is being read.
     * Prefer its authenticated ticket on a second read so that the ingress,
     * claim and retirement paths do not lose that transition. This snapshot
     * only owns local navigation; DeepLinkHost checks the SDK again to deliver.
     */
    private fun readTicketWitness(): TicketWitness? {
        ticketSource.currentTicket()?.let { return TicketWitness(it, restoring = false) }
        val provisional = ticketSource.provisionalStoredTicketDuringInitializing()
        ticketSource.currentTicket()?.let { return TicketWitness(it, restoring = false) }
        return provisional?.let { TicketWitness(it, restoring = true) }
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
