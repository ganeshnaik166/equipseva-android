package com.equipseva.app.navigation

import androidx.annotation.MainThread
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
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
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Owns the decision of whether a deep-link event should actually navigate.
 * The [DeepLinkRouter] produces raw events straight from the intent; this host
 * forwards them through the events SharedFlow to MainNavGraph.
 *
 * Marketplace order verification was stripped along with the marketplace
 * surface in the v1 cleanup. Today only push-notification kind→route events
 * flow through here; future cross-user verification (e.g. "engineer is allowed
 * to view this repair_job") can be added back as new branches in [init].
 */
@HiltViewModel
class DeepLinkHost @Inject constructor(
    router: DeepLinkRouter,
    private val userPrefs: UserPrefs,
    private val authRepository: AuthRepository,
    private val engineerRepository: EngineerRepository,
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
            AuthSession.SignedOut -> clearSession()
            AuthSession.Unknown -> clearSession()
            is AuthSession.SignedIn -> {
                val userId = session.userId.takeIf { it.isNotBlank() } ?: run {
                    clearSession()
                    return
                }
                val owner = activeSession?.takeIf { it.userId == userId }
                if (owner != null) return

                val freshOwner = LoginSession(userId, ++nextGeneration)
                activeSession = freshOwner
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
         * Pre-resolved in-app route from a notification tap. Forwarded as-is
         * — the FCM service already mapped the (kind, data) payload, and a
         * malformed kind is filtered out before we ever see it here.
         */
        data class OpenRoute(val route: String) : VerifiedEvent
    }

    // Channel + receiveAsFlow gives one-shot, buffered delivery so a deep
    // link emitted from MainActivity.onCreate() before MainNavGraph has
    // started collecting still reaches the nav graph. The previous
    // SharedFlow(replay=0) dropped any event emitted in that cold-start
    // window — push notifications taps that booted the app from a killed
    // state would land the user on the home screen instead of the deep
    // link. Buffered channel parks the event until first collection.
    private val _events = Channel<VerifiedEvent>(Channel.BUFFERED)
    val events: Flow<VerifiedEvent> = _events.receiveAsFlow()

    init {
        viewModelScope.launch {
            router.events.collect { raw ->
                when (raw) {
                    is DeepLinkRouter.Event.OpenRoute -> _events.trySend(VerifiedEvent.OpenRoute(raw.route))
                }
            }
        }
    }
}
