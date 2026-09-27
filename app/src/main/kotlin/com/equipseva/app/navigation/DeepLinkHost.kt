package com.equipseva.app.navigation

import androidx.annotation.MainThread
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.prefs.UserPrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Owns the decision of whether a deep-link event should actually navigate.
 * The [DeepLinkRouter] delivers an intent only to the currently mounted main
 * graph. This host stamps the observed login generation before queuing it.
 *
 * Marketplace order verification was stripped along with the marketplace
 * surface in the v1 cleanup. Today only push-notification kind→route events
 * flow through here; future cross-user verification (e.g. "engineer is allowed
 * to view this repair_job") can be added back as new branches in [init].
 */
@HiltViewModel
class DeepLinkHost @Inject constructor(
    private val router: DeepLinkRouter,
    private val userPrefs: UserPrefs,
    private val authRepository: AuthRepository,
    private val engineerRepository: EngineerRepository,
    private val loginTicketSource: LoginTicketSource,
) : ViewModel() {

    private data class LoginSession(
        val userId: String,
        val ticket: LoginTicketSnapshot?,
        val generation: Long,
    )
    private data class EngineerStatusRequest(val owner: LoginSession, val revision: Long)
    private data class SuspendedNavigation(
        val login: LoginSession,
        val launchOwner: DeepLinkRouter.LaunchOwner,
    )

    private val _engineerStatus = MutableStateFlow<VerificationStatus?>(null)
    val engineerStatus: StateFlow<VerificationStatus?> = _engineerStatus.asStateFlow()

    private var nextGeneration = 0L
    private var nextRevision = 0L
    private var activeSession: LoginSession? = null
    /** Navigation provenance only; Unknown still clears all A10 presentation state. */
    private var suspendedNavigation: SuspendedNavigation? = null
    private var activeRequest: EngineerStatusRequest? = null
    private var requestJob: Job? = null
    private var registeredOwner: DeepLinkRouter.LaunchOwner? = null
    private var registrationMarker: Any? = null

    val activeRole: Flow<String?> = userPrefs.activeRole

    /**
     * Engineer KYC verification status for the signed-in user, refreshed
     * on each observed login. Unknown retires the current owner: status stays
     * null until a fresh explicit SignedIn fetch succeeds. Loading, missing
     * engineer rows, failed refreshes, sign-out and blank IDs also yield null.
     * This is presentation state, not an authorization decision. Used by the
     * bottom nav to gate the Jobs tab — Pending → snackbar nudge instead of
     * navigating.
     */
    init {
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                onSession(session)
            }
        }
    }

    private fun onSession(session: AuthSession) {
        when (session) {
            AuthSession.SignedOut -> {
                val departing = activeSession ?: suspendedNavigation?.login
                router.retireStartupFor(
                    registeredOwner ?: suspendedNavigation?.launchOwner,
                    departing?.userId,
                )
                suspendedNavigation = null
                clearSession()
            }
            AuthSession.Unknown -> {
                // Initializing is normal before the first observed login.
                // Keep only the exact previous login's navigation provenance
                // for this Activity while the SDK restores. A10 status and
                // request ownership still retire immediately below.
                val departing = activeSession
                val launchOwner = registeredOwner
                if (departing?.ticket != null && launchOwner != null &&
                    router.isOwnerActive(launchOwner)
                ) {
                    suspendedNavigation = SuspendedNavigation(departing, launchOwner)
                }
                if (activeSession != null) {
                    router.retireStartupFor(
                        registeredOwner,
                        activeSession?.userId,
                        preserveInitializingRestoration = true,
                    )
                }
                clearSession()
            }
            is AuthSession.SignedIn -> {
                val userId = session.userId.takeIf { it.isNotBlank() } ?: run {
                    router.retireStartupFor(
                        registeredOwner ?: suspendedNavigation?.launchOwner,
                        activeSession?.userId ?: suspendedNavigation?.login?.userId,
                    )
                    suspendedNavigation = null
                    clearSession()
                    return
                }
                // The same account can sign in with a different Supabase
                // session without an intervening SignedOut emission. Treat
                // that exact-ticket change as a fresh login generation so a
                // buffered route from A1 cannot replay after an observed
                // A1 -> A2 -> A1 sequence.
                // A null ticket remains a duplicate of another null ticket;
                // engineer-status callers do not require a navigation ticket.
                val ticket = loginTicketSource.currentTicket()
                val suspended = suspendedNavigation
                suspendedNavigation = null
                val owner = activeSession?.takeIf { it.userId == userId && it.ticket == ticket }
                if (owner != null) {
                    // The SDK can restore an exact ticket while this host
                    // already presents the same user. Claim a provisional
                    // tap before treating the session event as a duplicate.
                    registeredOwner?.let { launchOwner ->
                        router.deliverStartupFor(launchOwner, userId, ::acceptRoute)
                    }
                    return
                }

                if (ticket != null && suspended != null && suspended.login.userId == userId &&
                    suspended.login.ticket == ticket &&
                    router.isOwnerActive(suspended.launchOwner) &&
                    (registeredOwner == null || registeredOwner === suspended.launchOwner)
                ) {
                    // The exact SDK login resumed after Unknown. Reuse its
                    // navigation generation, but start a fresh A10 status
                    // request because Unknown cleared presentation state.
                    activeSession = suspended.login
                    registeredOwner?.let { launchOwner ->
                        router.deliverStartupFor(launchOwner, userId, ::acceptRoute)
                    }
                    publishStatusFor(suspended.login)
                    return
                }

                if (suspended != null) {
                    router.retireStartupFor(suspended.launchOwner, suspended.login.userId)
                }

                // A direct A -> B emission is a boundary even when auth never
                // emits SignedOut/Unknown. Retire A's unclaimed launch before
                // installing B; a later A ticket must not reclaim that tap.
                activeSession?.let { departing ->
                    router.retireStartupFor(registeredOwner, departing.userId)
                }

                val freshOwner = LoginSession(userId, ticket, ++nextGeneration)
                activeSession = freshOwner
                registeredOwner?.let { launchOwner ->
                    router.deliverStartupFor(launchOwner, userId, ::acceptRoute)
                }
                publishStatusFor(freshOwner)
            }
        }
    }

    private fun clearSession() {
        activeRequest = null
        activeSession = null
        _engineerStatus.value = null
        requestJob?.cancel()
        requestJob = null
    }

    private fun publishStatusFor(owner: LoginSession) {
        val request = EngineerStatusRequest(owner, ++nextRevision)
        activeRequest = request
        _engineerStatus.value = null
        requestJob?.cancel()
        requestJob = viewModelScope.launch {
            if (!ownsRequest(request)) return@launch
            val status = try {
                engineerRepository.fetchByUserId(owner.userId)
                    .getOrThrow()
                    ?.verificationStatus
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                null
            }

            // Some repositories finish despite cancellation. Ownership also
            // protects observed A -> B -> A and same-login refresh revisions.
            coroutineContext.ensureActive()
            if (ownsRequest(request)) {
                _engineerStatus.value = status
            }
        }
    }

    private fun ownsRequest(request: EngineerStatusRequest): Boolean =
        activeRequest == request && activeSession == request.owner

    /**
     * Manual refresh — call after KYC submit so the badge flips to Pending
     * without waiting for a session re-emit. Snapshot the observed owner now;
     * never subscribe/await an account that may sign in later. All status
     * ownership is confined to Main, like the auth collector and UI callers.
     * Boundaries the repository never emits cannot be distinguished here.
     */
    @MainThread
    fun refreshEngineerStatus() {
        val owner = activeSession ?: return
        publishStatusFor(owner)
    }

    /**
     * Restorable last-screen route. MainNavGraph reads this once on cold
     * composition; if non-null, we navigate to it immediately so a
     * picker-induced process death drops the user back where they were.
     */
    val lastScreen: Flow<String?> = userPrefs.lastScreen

    /** Clear after restore so a Back / cold-start fallback lands at Home. */
    fun consumeLastScreen() {
        viewModelScope.launch { userPrefs.setLastScreen(null) }
    }

    sealed interface VerifiedEvent {
        /**
         * Pre-resolved route plus the exact SDK login ticket and observed
         * generation at ingress. These are local navigation provenance, not
         * permission to read the destination object from the server.
         */
        data class OpenRoute(
            val route: String,
            internal val ticket: LoginTicketSnapshot,
            internal val observedGeneration: Long,
            internal val launchOwner: DeepLinkRouter.LaunchOwner,
            internal val ingress: Long,
        ) : VerifiedEvent
    }

    // A mounted main graph or a ticket-bound one-shot launch may enter this queue.
    // The queue survives a collector delay, but its ownership is checked on
    // emission AND again immediately before navigation. A cold-start tap
    // without an SDK ticket is dropped rather than given to a later account.
    private val _events = Channel<VerifiedEvent>(Channel.BUFFERED)
    val events: Flow<VerifiedEvent> = _events.receiveAsFlow().filter(::isCurrent)

    /** Called only while MainNavGraph is in composition; close on disposal. */
    @MainThread
    fun registerRouterSink(
        owner: DeepLinkRouter.LaunchOwner = DeepLinkRouter.DEFAULT_OWNER,
    ): AutoCloseable {
        if (suspendedNavigation?.launchOwner?.let { it !== owner } == true) {
            suspendedNavigation = null
        }
        val marker = Any()
        val registration = router.registerAcknowledgingSink(owner, ::acceptRoute)
        registeredOwner = owner
        registrationMarker = marker
        // A retained ViewModel may have observed SignedIn before a new graph
        // registers. The one-shot claim still requires its exact SDK ticket.
        activeSession?.let { login ->
            router.deliverStartupFor(owner, login.userId, ::acceptRoute)
        }
        return AutoCloseable {
            registration.close()
            if (registrationMarker === marker) {
                registrationMarker = null
                registeredOwner = null
            }
        }
    }

    @MainThread
    private fun acceptRoute(raw: DeepLinkRouter.Event.OpenRoute): Boolean {
        val owner = activeSession ?: return false
        val launchOwner = registeredOwner ?: return false
        if (launchOwner !== raw.launchOwner || !router.isOwnerActive(launchOwner)) return false
        if (owner.userId != raw.ticket.userId || owner.ticket != raw.ticket ||
            loginTicketSource.currentTicket() != raw.ticket
        ) return false
        return _events.trySend(
            VerifiedEvent.OpenRoute(raw.route, raw.ticket, owner.generation, launchOwner, raw.ingress),
        ).isSuccess
    }

    /** Recheck at the final navigation boundary; the collector can resume after logout. */
    @MainThread
    fun isCurrent(event: VerifiedEvent): Boolean = when (event) {
        is VerifiedEvent.OpenRoute -> {
            val owner = activeSession
            val suspended = suspendedNavigation?.takeIf { it.launchOwner === event.launchOwner }
            val lineage = owner ?: suspended?.login
            val sameObservedLogin = lineage != null && lineage.userId == event.ticket.userId &&
                lineage.ticket == event.ticket &&
                lineage.generation == event.observedGeneration &&
                registeredOwner === event.launchOwner &&
                router.isOwnerActive(event.launchOwner)
            if (!sameObservedLogin) {
                false
            } else {
                val sdkTicket = loginTicketSource.currentTicket()
                if (owner != null && sdkTicket == event.ticket) {
                    true
                } else {
                    val raw = DeepLinkRouter.Event.OpenRoute(
                        route = event.route,
                        ticket = event.ticket,
                        launchOwner = event.launchOwner,
                        restoring = sdkTicket == null,
                        ingress = event.ingress,
                    )
                    // The channel consumes this event on a failed filter.
                    // Retain it only if the router still sees the exact
                    // provisional witness or SDK ticket at this ingress.
                    when {
                        sdkTicket == null -> router.deferVerifiedDuringRestoration(raw)
                        owner == null && sdkTicket == event.ticket ->
                            router.deferVerifiedForCurrentTicket(raw)
                        else -> Unit
                    }
                    false
                }
            }
        }
    }
}
