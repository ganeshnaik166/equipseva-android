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

    private data class LoginSession(val userId: String, val generation: Long)
    private data class EngineerStatusRequest(val owner: LoginSession, val revision: Long)

    private val _engineerStatus = MutableStateFlow<VerificationStatus?>(null)
    val engineerStatus: StateFlow<VerificationStatus?> = _engineerStatus.asStateFlow()

    private var nextGeneration = 0L
    private var nextRevision = 0L
    private var activeSession: LoginSession? = null
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
                router.retireStartupFor(registeredOwner, activeSession?.userId)
                clearSession()
            }
            AuthSession.Unknown -> {
                // Initializing is normal before the first observed login.
                // A later Unknown is a boundary and retires any old handoff.
                if (activeSession != null) {
                    router.retireStartupFor(registeredOwner, activeSession?.userId)
                }
                clearSession()
            }
            is AuthSession.SignedIn -> {
                val userId = session.userId.takeIf { it.isNotBlank() } ?: run {
                    router.retireStartupFor(registeredOwner, activeSession?.userId)
                    clearSession()
                    return
                }
                val owner = activeSession?.takeIf { it.userId == userId }
                if (owner != null) return

                // A direct A -> B emission is a boundary even when auth never
                // emits SignedOut/Unknown. Retire A's unclaimed launch before
                // installing B; a later A ticket must not reclaim that tap.
                activeSession?.let { departing ->
                    router.retireStartupFor(registeredOwner, departing.userId)
                }

                val freshOwner = LoginSession(userId, ++nextGeneration)
                activeSession = freshOwner
                registeredOwner?.let { launchOwner ->
                    router.takeStartupFor(launchOwner, userId)?.let(::acceptRoute)
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
        val marker = Any()
        val registration = router.registerSink(owner, ::acceptRoute)
        registeredOwner = owner
        registrationMarker = marker
        // A retained ViewModel may have observed SignedIn before a new graph
        // registers. The one-shot claim still requires its exact SDK ticket.
        activeSession?.let { login ->
            router.takeStartupFor(owner, login.userId)?.let(::acceptRoute)
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
    private fun acceptRoute(raw: DeepLinkRouter.Event.OpenRoute) {
        val owner = activeSession ?: return
        val launchOwner = registeredOwner ?: return
        if (launchOwner !== raw.launchOwner || !router.isOwnerActive(launchOwner)) return
        if (owner.userId != raw.ticket.userId || loginTicketSource.currentTicket() != raw.ticket) return
        _events.trySend(VerifiedEvent.OpenRoute(raw.route, raw.ticket, owner.generation, launchOwner))
    }

    /** Recheck at the final navigation boundary; the collector can resume after logout. */
    @MainThread
    fun isCurrent(event: VerifiedEvent): Boolean = when (event) {
        is VerifiedEvent.OpenRoute -> {
            val owner = activeSession
            owner != null && owner.userId == event.ticket.userId &&
                owner.generation == event.observedGeneration &&
                registeredOwner === event.launchOwner &&
                router.isOwnerActive(event.launchOwner) &&
                loginTicketSource.currentTicket() == event.ticket
        }
    }
}
