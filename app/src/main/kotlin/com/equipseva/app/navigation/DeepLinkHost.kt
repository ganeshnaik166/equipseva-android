package com.equipseva.app.navigation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.prefs.UserPrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
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

    val activeRole: Flow<String?> = userPrefs.activeRole

    /**
     * Engineer KYC verification status for the signed-in user, refreshed
     * on every sign-in. `null` while loading, when the user isn't an
     * engineer, or when signed out. Used by the bottom nav to gate the
     * Jobs tab — Pending → snackbar nudge instead of navigating.
     */
    private val _engineerStatus = MutableStateFlow<VerificationStatus?>(null)
    val engineerStatus: StateFlow<VerificationStatus?> = _engineerStatus.asStateFlow()

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    val status = engineerRepository.fetchByUserId(session.userId)
                        .getOrNull()
                        ?.verificationStatus
                    _engineerStatus.value = status
                }
        }
    }

    /** Manual refresh — call after KYC submit so the badge flips to Pending
     *  without waiting for a session re-emit. */
    fun refreshEngineerStatus() {
        viewModelScope.launch {
            val uid = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()?.userId ?: return@launch
            _engineerStatus.value = engineerRepository.fetchByUserId(uid)
                .getOrNull()?.verificationStatus
        }
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
