package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.annotation.MainThread
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Bridge between [android.app.Activity.onNewIntent] / launch intents and the
 * Compose nav graph. The activity calls [dispatch] on each intent; the main
 * nav graph collects [events] (via [DeepLinkHost]) and navigates accordingly.
 *
 * Two entry points handled, in priority order:
 *  1. [EXTRA_ROUTE] string extra — stamped by the FCM service after running
 *     NotificationDeepLink. Accepted ONLY when [DeepLinkPolicy.isExternallyAllowed]
 *     (A3-01): the exported activity cannot tell its own PendingIntent from an
 *     explicit intent any installed app can fire, so the extra is treated as
 *     untrusted input, never as a navigation command.
 *  2. [Intent.getData] HTTPS URI on `equipseva.com` / `www.equipseva.com` — the
 *     App Link path declared with autoVerify=true in the manifest. A small
 *     whitelist of paths maps to nav routes; anything else is ignored so the
 *     app falls back to its default landing screen.
 *
 * Ownership (A3-02). Internal envelopes retain a user and observed login
 * generation through both this router's and [DeepLinkHost]'s buffers. Delivery
 * rechecks immediate auth, so an observed A -> B -> A cannot replay A's old tap.
 * Only the initial Unknown may queue cold-start taps (the first 32, in order).
 * Later Unknown, sign-out, blank IDs and explicit [clear] retire the owner and
 * discard pending taps. Same-account email changes keep the current generation.
 * A same-ID login boundary wholly unobserved by the upstream auth flow remains
 * indistinguishable from a refresh; this is not server authorization. All
 * ownership mutation and delivery are Main-confined, like activity dispatch.
 * An optional [EXTRA_RECIPIENT_USER_ID] that disagrees with the signed-in user
 * drops the event; every destination still keeps its server-side checks.
 */
@Singleton
class DeepLinkRouter(
    private val authRepository: AuthRepository,
    private val scope: CoroutineScope,
    /** Diagnostics sink; production logs to logcat, JVM tests pass a recorder (android.util.Log is a stub there). */
    private val onLog: (String) -> Unit,
) {

    @Inject
    constructor(authRepository: AuthRepository) : this(
        authRepository,
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
        { Log.i(TAG, it) },
    )

    sealed interface Event {
        /**
         * A pre-resolved route string the nav graph can navigate directly to,
         * bound to [ownerUserId]. The immutable login generation is retained by
         * an internal envelope until delivery; callers keep this value API.
         */
        data class OpenRoute(val route: String, val ownerUserId: String) : Event
    }

    private data class Pending(val route: String, val recipientUserId: String?)

    internal data class Login(val userId: String, val generation: Long)
    internal data class OwnedRoute(val event: Event.OpenRoute, val login: Login)

    private val channel = Channel<OwnedRoute>(Channel.BUFFERED)
    internal val ownedEvents: Flow<OwnedRoute> = channel.receiveAsFlow()
        .filter { isCurrentLogin(it.login) }
    val events: Flow<Event> = ownedEvents.map { it.event }

    /** Only initial Unknown can queue taps; later Unknown must never adopt them into another login. */
    private val pendingUntilResolved = ArrayDeque<Pending>()
    private var initialResolution = true
    private var nextGeneration = 0L
    private var activeLogin: Login? = null
    private var clearedUserId: String? = null

    init {
        // Observe directly: a second stateIn layer adds another opportunity for
        // identity transitions to be conflated. No network work runs here.
        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            authRepository.sessionState.collect(::observeSession)
        }
    }

    @MainThread
    fun dispatch(intent: Intent?) {
        if (intent == null) return
        val explicit = intent.getStringExtra(EXTRA_ROUTE)?.takeIf { it.isNotBlank() }
        val route = explicit?.takeIf(DeepLinkPolicy::isExternallyAllowed)
            ?: routeFor(intent.data)
            ?: routeFromPushExtras(intent)
        if (route == null) {
            // Denied external routes are logged without their content: an attacker-
            // supplied route string is exactly what we do not want in the logs.
            if (explicit != null) onLog("Denied external route (${explicit.length} chars)")
            return
        }
        val recipient = intent.getStringExtra(EXTRA_RECIPIENT_USER_ID)?.takeIf { it.isNotBlank() }
            ?: intent.getStringExtra("user_id")?.takeIf { it.isNotBlank() }
        dispatchRoute(route, recipient)
    }

    /**
     * Background-tap fallback. When the server sends a `notification` block, FCM
     * posts the tray entry itself for a backgrounded/killed app and delivers the
     * raw `data` map as launcher extras — our service never runs, so there is no
     * [EXTRA_ROUTE]. Re-run the same pure mapper the service uses over those
     * extras, then apply the same external allow-list. Without this every
     * notification tap from the background landed on Home.
     */
    private fun routeFromPushExtras(intent: Intent): String? {
        val extras = intent.extras ?: return null
        val kind = extras.getString("kind")?.takeIf { it.isNotBlank() } ?: return null
        val data = buildMap<String, String> {
            for (key in extras.keySet()) {
                extras.getString(key)?.let { put(key, it) }
            }
        }
        return NotificationDeepLink.routeFor(kind, data)?.takeIf(DeepLinkPolicy::isExternallyAllowed)
    }

    /**
     * Pure core of [dispatch] (visible for testing): routes an already-validated
     * [route] according to the current session.
     */
    @MainThread
    internal fun dispatchRoute(route: String, recipientUserId: String?) {
        when (synchronizeCurrentSession()) {
            is AuthSession.SignedIn -> {
                val login = activeLogin
                if (login != null) enqueue(route, recipientUserId, login)
                else onLog("Dropped a deep link without an active login")
            }
            AuthSession.Unknown -> {
                if (initialResolution && pendingUntilResolved.size < MAX_PENDING_ROUTES) {
                    pendingUntilResolved.addLast(Pending(route, recipientUserId))
                } else {
                    onLog("Dropped a deep link while auth was unresolved or its queue was full")
                }
            }
            AuthSession.SignedOut -> onLog("Dropped a deep link that arrived while signed out")
            null -> onLog("Dropped a deep link because current auth was unavailable")
        }
    }

    /**
     * Retire even events already parked in a host. Sign-out cleanup can run
     * before the SDK clears A, so the same cached A cannot rearm this router;
     * an observed auth boundary must occur first.
     */
    @MainThread
    fun clear() {
        clearedUserId = when (val current = readCurrentSession()) {
            is AuthSession.SignedIn -> current.userId.takeIf { it.isNotBlank() }
            null -> activeLogin?.userId
            else -> null
        }
        initialResolution = false
        retireLogin()
    }

    private fun observeSession(current: AuthSession) {
        when (current) {
            AuthSession.Unknown -> {
                if (!initialResolution) {
                    clearedUserId = null
                    retireLogin()
                }
            }
            AuthSession.SignedOut -> {
                initialResolution = false
                clearedUserId = null
                retireLogin()
            }
            is AuthSession.SignedIn -> {
                val userId = current.userId.takeIf { it.isNotBlank() }
                if (userId == null) {
                    initialResolution = false
                    clearedUserId = null
                    retireLogin()
                    return
                }
                if (clearedUserId == userId) {
                    retireLogin()
                    return
                }
                clearedUserId = null
                if (activeLogin?.userId == userId) return

                val wasInitialResolution = initialResolution
                initialResolution = false
                if (!wasInitialResolution) retireLogin()
                val login = Login(userId, ++nextGeneration)
                activeLogin = login
                if (wasInitialResolution) flushPending(login)
            }
        }
    }

    private fun retireLogin() {
        activeLogin = null
        pendingUntilResolved.clear()
        while (channel.tryReceive().isSuccess) { /* drain */ }
    }

    /** Called again by the host immediately before exposing its buffered event to navigation. */
    @MainThread
    internal fun isCurrentLogin(login: Login): Boolean {
        synchronizeCurrentSession()
        return activeLogin == login
    }

    private fun synchronizeCurrentSession(): AuthSession? {
        val current = readCurrentSession()
        if (current == null) {
            // A delayed/non-replaying source is not permission to wait for a
            // future account. Retire ownership and close cold-start buffering.
            initialResolution = false
            retireLogin()
        } else {
            observeSession(current)
        }
        return current
    }

    private fun readCurrentSession(): AuthSession? {
        var current: AuthSession? = null
        val probe = scope.launch(start = CoroutineStart.UNDISPATCHED) {
            try {
                coroutineContext.ensureActive()
                current = authRepository.sessionState.first()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                // Auth that cannot be read immediately must fail closed.
            }
        }
        val completed = probe.isCompleted && !probe.isCancelled
        probe.cancel()
        return current.takeIf { completed }
    }

    private fun flushPending(login: Login) {
        while (pendingUntilResolved.isNotEmpty()) {
            val next = pendingUntilResolved.removeFirst()
            enqueue(next.route, next.recipientUserId, login)
        }
    }

    private fun enqueue(route: String, recipientUserId: String?, login: Login) {
        if (recipientUserId != null && recipientUserId != login.userId) {
            onLog("Dropped a deep link addressed to a different account")
            return
        }
        if (channel.trySend(OwnedRoute(Event.OpenRoute(route, login.userId), login)).isFailure) {
            onLog("Dropped a deep link because the delivery buffer was full")
        }
    }

    companion object {
        private const val TAG = "DeepLinkRouter"
        private const val MAX_PENDING_ROUTES = 32
        const val EXTRA_ROUTE = "com.equipseva.app.deeplink.ROUTE"

        /**
         * Recipient `user_id` copied from the push payload by the FCM service when
         * the server includes it. Absent on links that carry no recipient (App Links).
         */
        const val EXTRA_RECIPIENT_USER_ID = "com.equipseva.app.deeplink.RECIPIENT_USER_ID"

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
