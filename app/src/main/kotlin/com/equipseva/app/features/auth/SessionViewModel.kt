package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.SignOutCleanup
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.push.DeviceTokenRegistrar
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject

/**
 * Root navigation state. Role and onboarding are published together from a
 * profile validated for the current login. Device-global preferences have no
 * owner, so their initial or delayed emissions cannot establish this identity.
 * Role/onboarding writers must call [refreshNow] after a successful server save.
 * Wiring the existing RoleSelect/SignUp/Profile/hub writers is separate A2/A4
 * work; their preference writes alone no longer advance this navigation gate.
 */
@HiltViewModel
class SessionViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
    private val deviceTokenRegistrar: DeviceTokenRegistrar,
    private val signOutCleanup: SignOutCleanup,
) : ViewModel() {

    /**
     * AuthSession exposes userId/email, not the SDK's login identity. This local
     * generation changes on every observed sign-out or account replacement,
     * including A -> SignedOut -> A and A -> B -> A. Unknown preserves the login
     * while work waits for auth to resolve; duplicate SignedIn/email updates do
     * not create a login. An upstream StateFlow can conflate an entire boundary:
     * if SignedOut/B is never observed, a same-ID relogin is indistinguishable
     * from token refresh. Closing that boundary needs repository-level identity.
     * All ownership changes and effect admissions run on viewModelScope's Main.
     */
    private data class Login(val userId: String, val generation: Long)
    private data class ProfileRequest(val login: Login, val revision: Long)
    private data class ProfileGate(
        val role: String?,
        val onboarded: Boolean,
        val baseDone: Boolean,
    )
    private data class Snapshot(
        val session: AuthSession = AuthSession.Unknown,
        val login: Login? = null,
        val profile: ProfileGate? = null,
        val revoking: Boolean = false,
    )

    private val snapshot = MutableStateFlow(Snapshot())
    private var loginGeneration = 0L
    private var fetchRevision = 0L
    private var latestRequest: ProfileRequest? = null
    private var profileJob: Job? = null
    private var tokenJob: Job? = null
    private var signedOutPrefsJob: Job? = null
    private val preferenceWrites = Mutex()

    // No replay: a deletion toast must not reappear in a later login.
    private val _messages = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val messages: kotlinx.coroutines.flow.Flow<String> = _messages

    val tourSeen: StateFlow<Boolean> = userPrefs.observeTourSeen().stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = true,
    )

    /** Base phone/state/district gate, independently of engineer payout setup. */
    val profileBaseV2Done: StateFlow<Boolean> = snapshot.map {
        it.profile?.baseDone == true
    }.stateIn(viewModelScope, SharingStarted.Eagerly, false)

    val state: StateFlow<SessionState> = snapshot.map { current ->
        when (val session = current.session) {
            AuthSession.Unknown -> SessionState.Loading
            AuthSession.SignedOut -> SessionState.SignedOut
            is AuthSession.SignedIn -> {
                val profile = current.profile
                when {
                    current.login == null || profile == null || current.revoking -> SessionState.Loading
                    profile.role.isNullOrBlank() -> SessionState.NeedsRole(session.userId, session.email)
                    profile.onboarded -> SessionState.Ready(session.userId, session.email, profile.role)
                    else -> SessionState.NeedsOnboarding(session.userId, session.email, profile.role)
                }
            }
        }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, SessionState.Loading)

    // Keep init after every state field: Main.immediate may collect immediately
    // during construction, including when dependencies finish synchronously.
    init {
        viewModelScope.launch {
            // Never suspend this collector on token, profile, or preference I/O.
            // Cancel-and-join/collectLatest can block a new login behind an old
            // dependency that swallows cancellation. Ownership is the backstop.
            authRepository.sessionState.collect { session -> observeSession(session) }
        }
    }

    private fun observeSession(session: AuthSession) {
        val previous = snapshot.value
        when (session) {
            AuthSession.Unknown -> snapshot.value = previous.copy(session = session)
            AuthSession.SignedOut -> {
                if (previous.session == AuthSession.SignedOut) return
                val signedOutGeneration = ++loginGeneration
                snapshot.value = Snapshot(session = session)
                cancelLoginWork()
                signedOutPrefsJob = viewModelScope.launch {
                    try {
                        preferenceWrites.withLock {
                            if (!isCurrentSignOut(signedOutGeneration)) return@withLock
                            userPrefs.clearActiveRole()
                            currentCoroutineContext().ensureActive()
                            if (!isCurrentSignOut(signedOutGeneration)) return@withLock
                            userPrefs.setV2OnboardingComplete(false)
                        }
                    } catch (ce: CancellationException) {
                        throw ce
                    } catch (_: Exception) {
                        // SignedOut stays authoritative if disk cleanup fails.
                        // The next login must validate and replace both mirrors.
                    }
                }
            }
            is AuthSession.SignedIn -> {
                if (session.userId.isBlank()) {
                    ++loginGeneration
                    snapshot.value = Snapshot(session = session)
                    cancelLoginWork()
                } else if (previous.login?.userId == session.userId) {
                    snapshot.value = previous.copy(session = session)
                } else {
                    val login = Login(session.userId, ++loginGeneration)
                    // Establish the loading fence and discard A's entire gate
                    // before any suspending work for B is launched.
                    snapshot.value = Snapshot(session = session, login = login)
                    cancelLoginWork()
                    startProfileRequest(login)
                    startTokenRegistration(login)
                }
            }
        }
    }

    private fun cancelLoginWork() {
        latestRequest = null
        profileJob?.cancel()
        tokenJob?.cancel()
        signedOutPrefsJob?.cancel()
    }

    private suspend fun isCurrentSignOut(generation: Long): Boolean {
        val live = authRepository.sessionState.first()
        currentCoroutineContext().ensureActive()
        return loginGeneration == generation && snapshot.value.session == AuthSession.SignedOut &&
            live == AuthSession.SignedOut
    }

    /**
     * Called on foreground and after role/onboarding saves. A refresh failure
     * retains an already validated same-login snapshot. A first fetch failure
     * remains gated until a retry succeeds: the persisted cache has no owner.
     */
    fun refreshNow() {
        viewModelScope.launch {
            val current = snapshot.value
            val login = current.login ?: return@launch
            if (current.session !is AuthSession.SignedIn || current.revoking) return@launch
            startProfileRequest(login)
        }
    }

    private fun startProfileRequest(login: Login) {
        val request = ProfileRequest(login, ++fetchRevision)
        latestRequest = request
        profileJob?.cancel()
        profileJob = viewModelScope.launch {
            try {
                bootstrapProfile(request)
            } finally {
                // An old request cannot release the new request or its loading
                // fence. Only an owned successful profile resolves that fence.
                if (ownsRequest(request)) {
                    latestRequest = null
                    profileJob = null
                }
            }
        }
    }

    private fun startTokenRegistration(login: Login) {
        tokenJob = viewModelScope.launch {
            if (!isLiveLogin(login) || snapshot.value.revoking) return@launch
            // Best-effort registration for each observed login. The loading
            // fence and profile request do not depend on token I/O completing.
            try {
                deviceTokenRegistrar.refresh()
            } catch (ce: CancellationException) {
                throw ce
            } catch (_: Throwable) {
                // Network/Play Services failures do not block profile bootstrap.
            }
        }
    }

    private fun ownsRequest(request: ProfileRequest): Boolean =
        latestRequest == request && snapshot.value.login == request.login

    /**
     * Wait through Unknown without losing the pending result. Read auth again
     * before an effect: a response can resume before the queued auth observer,
     * even though upstream has already switched to B or SignedOut. The local
     * generation additionally rejects observed same-account relogins; a live
     * user-ID read alone cannot detect that ABA boundary.
     */
    private suspend fun isLiveLogin(login: Login): Boolean {
        while (true) {
            snapshot.first { it.login != login || it.session !is AuthSession.Unknown }
            currentCoroutineContext().ensureActive()
            if (snapshot.value.login != login) return false
            val live = authRepository.sessionState.first { it !is AuthSession.Unknown }
            currentCoroutineContext().ensureActive()
            val observed = snapshot.value
            if (live !is AuthSession.SignedIn || live.userId != login.userId || observed.login != login) {
                return false
            }
            // Unknown may have arrived while the live read suspended. Let the
            // full observer resolve it; do not strand the initial bootstrap.
            if (observed.session is AuthSession.Unknown) continue
            return observed.session is AuthSession.SignedIn
        }
    }

    private suspend fun mayPublish(request: ProfileRequest): Boolean =
        isLiveLogin(request.login) && ownsRequest(request)

    private suspend fun bootstrapProfile(request: ProfileRequest) {
        if (!mayPublish(request)) return
        val result = profileRepository.fetchById(request.login.userId)
        if (!mayPublish(request)) return
        // Some repositories wrap cancellation in Result; never turn that into
        // successful completion or permission to publish a stale profile.
        (result.exceptionOrNull() as? CancellationException)?.let { throw it }
        if (result.isFailure) return
        val fetched = result.getOrNull()
        if (fetched != null && fetched.id != request.login.userId) return

        if (fetched == null || !fetched.isActive) {
            // Remain gated if signOut fails or the auth emission is delayed;
            // refresh/duplicate SignedIn cannot repeat deletion side effects.
            snapshot.value = snapshot.value.copy(profile = null, revoking = true)
            tokenJob?.cancel()
            if (!mayPublish(request)) return
            _messages.tryEmit(
                if (fetched == null) "Your account is no longer active. Sign in again."
                else "This account was deleted. Contact support to restore it.",
            )
            if (!mayPublish(request)) return
            signOutCleanup.wipeLocalUserState()
            // A1 fences admission and this subsequent signOut. Already-started
            // SignOutCleanup swallows cancellation and globally wipes stores;
            // making those internal writes login-aware is a separate boundary.
            if (!mayPublish(request)) return
            try {
                authRepository.signOut()
            } catch (ce: CancellationException) {
                throw ce
            } catch (_: Throwable) {
                // Best-effort after cleanup; the deleted login stays gated.
            }
            return
        }

        val profile = ProfileGate(
            // active_role takes precedence over the trigger's scalar default.
            role = fetched.takeIf { it.roleConfirmed }
                ?.let { it.activeRoleKey ?: it.rawRoleKey }?.takeUnless { it.isBlank() },
            onboarded = fetched.hasCompletedV2Onboarding,
            baseDone = !fetched.phone.isNullOrBlank() &&
                !fetched.state.isNullOrBlank() && !fetched.district.isNullOrBlank(),
        )
        try {
            preferenceWrites.withLock {
                if (!mayPublish(request)) return@withLock
                if (profile.role == null) userPrefs.clearActiveRole()
                else userPrefs.setActiveRole(profile.role)
                if (!mayPublish(request)) return@withLock
                userPrefs.setV2OnboardingComplete(profile.onboarded)
                if (!mayPublish(request)) return@withLock
                // SecurePrefs can publish role before its suspending DataStore
                // edit returns. Routing observes only this atomic owned gate.
                snapshot.value = snapshot.value.copy(profile = profile)
            }
        } catch (ce: CancellationException) {
            throw ce
        } catch (_: Exception) {
            // Other hosts still read these mirrors directly. Do not promote a
            // new gate after a failed write, or crash Main on storage I/O.
            // Retain the same-login validated gate (initially Loading) and let
            // refreshNow retry the required mirrors and atomic publication.
        }
    }
}

sealed interface SessionState {
    data object Loading : SessionState
    data object SignedOut : SessionState
    data class NeedsRole(val userId: String, val email: String?) : SessionState

    /** Signed in with a confirmed role; mandatory profile/payout setup remains. */
    data class NeedsOnboarding(
        val userId: String,
        val email: String?,
        val role: String,
    ) : SessionState

    data class Ready(val userId: String, val email: String?, val role: String) : SessionState
}
