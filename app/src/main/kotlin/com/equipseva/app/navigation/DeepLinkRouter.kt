package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import android.util.Log
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
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
 * Ownership (A3-02). Every event is stamped with the user that was signed in
 * when it was dispatched, and [DeepLinkHost] delivers it only to that owner's
 * MAIN. Links that arrive while auth is still resolving (cold start from a tray
 * tap) are queued IN ORDER and stamped when the first `SignedIn` arrives, so a
 * legitimate cold-start tap is preserved. Links that arrive while signed out are
 * dropped, and a sign-out clears both the queue and the buffered channel —
 * nothing dispatched under A can surface inside B's session, or inside A's next
 * login. An optional [EXTRA_RECIPIENT_USER_ID] (set by the FCM service from the
 * push payload) that disagrees with the signed-in user drops the event: that is
 * identity de-duplication, not authorization — every destination keeps its
 * server-side checks.
 */
@Singleton
class DeepLinkRouter(
    private val authRepository: AuthRepository,
    scope: CoroutineScope,
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
         * bound to the login ([ownerUserId]) that was current when it was dispatched.
         */
        data class OpenRoute(val route: String, val ownerUserId: String) : Event
    }

    private data class Pending(val route: String, val recipientUserId: String?)

    private val channel = Channel<Event>(Channel.BUFFERED)
    val events: Flow<Event> = channel.receiveAsFlow()

    /** Routes dispatched while the session was still [AuthSession.Unknown]; stamped on first SignedIn. */
    private val pendingUntilResolved = ArrayDeque<Pending>()

    private val session: StateFlow<AuthSession> =
        authRepository.sessionState.stateIn(scope, SharingStarted.Eagerly, AuthSession.Unknown)

    init {
        scope.launch {
            session.collect { current ->
                when (current) {
                    AuthSession.SignedOut -> clear()
                    is AuthSession.SignedIn -> flushPending(current.userId)
                    AuthSession.Unknown -> Unit
                }
            }
        }
    }

    fun dispatch(intent: Intent?) {
        if (intent == null) return
        val explicit = intent.getStringExtra(EXTRA_ROUTE)?.takeIf { it.isNotBlank() }
        val route = explicit?.takeIf(DeepLinkPolicy::isExternallyAllowed) ?: routeFor(intent.data)
        if (route == null) {
            // Denied external routes are logged without their content: an attacker-
            // supplied route string is exactly what we do not want in the logs.
            if (explicit != null) onLog("Denied external route (${explicit.length} chars)")
            return
        }
        dispatchRoute(route, intent.getStringExtra(EXTRA_RECIPIENT_USER_ID)?.takeIf { it.isNotBlank() })
    }

    /**
     * Pure core of [dispatch] (visible for testing): routes an already-validated
     * [route] according to the current session.
     */
    internal fun dispatchRoute(route: String, recipientUserId: String?) {
        when (val current = session.value) {
            is AuthSession.SignedIn -> enqueue(route, recipientUserId, current.userId)
            AuthSession.Unknown -> pendingUntilResolved.addLast(Pending(route, recipientUserId))
            AuthSession.SignedOut -> onLog("Dropped a deep link that arrived while signed out")
        }
    }

    /** Drop everything that has not been delivered yet. Called on sign-out. */
    fun clear() {
        pendingUntilResolved.clear()
        while (channel.tryReceive().isSuccess) { /* drain */ }
    }

    private fun flushPending(userId: String) {
        if (userId.isBlank()) return
        while (pendingUntilResolved.isNotEmpty()) {
            val next = pendingUntilResolved.removeFirst()
            enqueue(next.route, next.recipientUserId, userId)
        }
    }

    private fun enqueue(route: String, recipientUserId: String?, ownerUserId: String) {
        if (ownerUserId.isBlank()) return
        if (recipientUserId != null && recipientUserId != ownerUserId) {
            onLog("Dropped a deep link addressed to a different account")
            return
        }
        channel.trySend(Event.OpenRoute(route, ownerUserId))
    }

    companion object {
        private const val TAG = "DeepLinkRouter"
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
