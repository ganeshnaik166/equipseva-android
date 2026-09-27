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
 * Root routing uses a profile validated for the observed login, never the
 * device-global role/onboarding mirrors. Those mirrors can belong to the last
 * account on a shared device. AuthSession exposes no SDK login ID, so a local
 * generation distinguishes observed A -> out -> A and A -> B -> A boundaries;
 * an entire boundary conflated upstream remains a repository-level gap.
 */
@HiltViewModel
class SessionViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
    private val deviceTokenRegistrar: DeviceTokenRegistrar,
    private val signOutCleanup: SignOutCleanup,
) : ViewModel() {
    private data class Login(val userId: String, val generation: Long)
    private data class Request(val login: Login, val revision: Long)
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
        val revalidating: Boolean = false,
        val verificationFailed: Boolean = false,
    )

    private val snapshot = MutableStateFlow(Snapshot())
    private var loginGeneration = 0L
    private var requestRevision = 0L
    private var latestRequest: Request? = null
    private var profileJob: Job? = null
    private var tokenJob: Job? = null
    private var signedOutPrefsJob: Job? = null
    private val preferenceWrites = Mutex()

    // A toast emitted while the root graph is absent cannot replay on a later login.
    private val _messages = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val messages: kotlinx.coroutines.flow.Flow<String> = _messages

    val tourSeen: StateFlow<Boolean> = userPrefs.observeTourSeen().stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = true,
    )

    val profileBaseV2Done: StateFlow<Boolean> = snapshot.map { it.profile?.baseDone == true }
        .stateIn(viewModelScope, SharingStarted.Eagerly, false)

    /** One atomic root input: separately collected owner/state could briefly mismatch. */
    private fun presentationFor(current: Snapshot): SessionPresentation =
        SessionPresentation(
            state = rootState(current),
            owner = current.login?.let { SessionOwner(it.userId, it.generation) },
            validatedRole = current.profile?.role?.let(UserRole::fromKey),
            profileValidated = current.profile != null && !current.revoking,
            resolvingAuth = current.session == AuthSession.Unknown || current.revalidating,
            verificationFailed = current.verificationFailed,
        )

    /** Synchronous boundary check for callbacks before StateFlow/Compose delivery. */
    internal fun currentPresentation(): SessionPresentation = presentationFor(snapshot.value)

    val presentation: StateFlow<SessionPresentation> = snapshot.map(::presentationFor)
        .stateIn(viewModelScope, SharingStarted.Eagerly, SessionPresentation())

    val state: StateFlow<SessionState> = presentation.map { it.state }
        .stateIn(viewModelScope, SharingStarted.Eagerly, SessionState.Loading)

    // Keep init after all state fields: Main.immediate can collect during construction.
    init {
        viewModelScope.launch {
            // No network, token, or preference I/O in this collector. A slow or
            // cancellation-ignoring A request must not block observation of B.
            authRepository.sessionState.collect(::observeSession)
        }
    }

    private fun rootState(current: Snapshot): SessionState = when (val session = current.session) {
        AuthSession.Unknown -> SessionState.Loading
        AuthSession.SignedOut -> SessionState.SignedOut
        is AuthSession.SignedIn -> {
            val profile = current.profile
            when {
                current.login == null || profile == null || current.revoking -> SessionState.Loading
                profile.role.isNullOrBlank() || UserRole.fromKey(profile.role) !in
                    setOf(UserRole.HOSPITAL, UserRole.ENGINEER) ->
                    SessionState.NeedsRole(session.userId, session.email)
                profile.onboarded -> SessionState.Ready(session.userId, session.email, profile.role)
                else -> SessionState.NeedsOnboarding(session.userId, session.email, profile.role)
            }
        }
    }

    private fun observeSession(session: AuthSession) {
        val previous = snapshot.value
        when (session) {
            AuthSession.Unknown -> snapshot.value = previous.copy(
                session = session,
                revalidating = previous.profile != null,
            )
            AuthSession.SignedOut -> {
                if (previous.session == AuthSession.SignedOut) return
                val generation = ++loginGeneration
                cancelLoginWork()
                snapshot.value = Snapshot(session = session)
                signedOutPrefsJob = viewModelScope.launch {
                    try {
                        preferenceWrites.withLock {
                            if (!isLiveSignedOut(generation)) return@withLock
                            userPrefs.clearActiveRole()
                            if (!isLiveSignedOut(generation)) return@withLock
                            userPrefs.setV2OnboardingComplete(false)
                        }
                    } catch (ce: CancellationException) {
                        throw ce
                    } catch (_: Exception) {
                        // The signed-out root gate remains authoritative.
                    }
                }
            }
            is AuthSession.SignedIn -> {
                if (session.userId.isBlank()) {
                    ++loginGeneration
                    cancelLoginWork()
                    snapshot.value = Snapshot(session = session)
                } else if (previous.login?.userId == session.userId) {
                    // Duplicate emissions and email-only changes are one login.
                    snapshot.value = previous.copy(session = session)
                    if (previous.session == AuthSession.Unknown && previous.profile != null) {
                        startProfileRequest(previous.login)
                    }
                } else {
                    val login = Login(session.userId, ++loginGeneration)
                    cancelLoginWork()
                    // Clear A's entire gate before launching any suspending B work.
                    snapshot.value = Snapshot(session = session, login = login)
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

    /** A manual refresh never waits for a future account or an Unknown session. */
    fun refreshNow() {
        val current = snapshot.value
        val login = current.login ?: return
        if (current.session !is AuthSession.SignedIn || current.revoking) return
        // The cover must raise in this same UI turn before a phone-completion
        // callback can hand off using the previously validated profile.
        startProfileRequest(login)
    }

    private fun startProfileRequest(login: Login) {
        val current = snapshot.value
        if (current.login == login) {
            snapshot.value = current.copy(
                revalidating = current.profile != null,
                verificationFailed = false,
            )
        }
        val request = Request(login, ++requestRevision)
        latestRequest = request
        profileJob?.cancel()
        profileJob = viewModelScope.launch {
            try {
                bootstrapProfile(request)
            } finally {
                if (latestRequest == request) {
                    latestRequest = null
                    profileJob = null
                }
            }
        }
    }

    private fun startTokenRegistration(login: Login) {
        tokenJob = viewModelScope.launch {
            if (!isLiveLogin(login)) return@launch
            try {
                deviceTokenRegistrar.refresh()
            } catch (ce: CancellationException) {
                throw ce
            } catch (_: Throwable) {
                // Best effort; token registration cannot hold up profile routing.
            }
        }
    }

    private suspend fun isLiveSignedOut(generation: Long): Boolean {
        val live = authRepository.sessionState.first { it !is AuthSession.Unknown }
        currentCoroutineContext().ensureActive()
        return loginGeneration == generation && snapshot.value.session == AuthSession.SignedOut &&
            live == AuthSession.SignedOut
    }

    /**
     * A response may resume before the auth observer sees the queued switch.
     * Check both the observed generation and the latest upstream identity.
     * Unknown pauses background work for its existing login; sign-out or a
     * replacement invalidates it. No local observer can detect a transition
     * that the repository's StateFlow entirely conflates.
     */
    private suspend fun isLiveLogin(login: Login): Boolean {
        while (true) {
            val current = snapshot.value
            if (current.login != login) return false
            if (current.session is AuthSession.Unknown) {
                snapshot.first { it.login != login || it.session !is AuthSession.Unknown }
                currentCoroutineContext().ensureActive()
                continue
            }
            val live = authRepository.sessionState.first { it !is AuthSession.Unknown }
            currentCoroutineContext().ensureActive()
            val observed = snapshot.value
            if (observed.login != login || live !is AuthSession.SignedIn || live.userId != login.userId) {
                return false
            }
            if (observed.session is AuthSession.Unknown) continue
            return observed.session is AuthSession.SignedIn
        }
    }

    private suspend fun owns(request: Request): Boolean =
        latestRequest == request && isLiveLogin(request.login) && latestRequest == request

    private suspend fun bootstrapProfile(request: Request) {
        if (!owns(request)) return
        val result = try {
            profileRepository.fetchById(request.login.userId)
        } catch (ce: CancellationException) {
            throw ce
        } catch (_: Exception) {
            markVerificationFailed(request)
            return
        }
        if (!owns(request)) return
        (result.exceptionOrNull() as? CancellationException)?.let { throw it }
        if (result.isFailure) {
            markVerificationFailed(request)
            return
        }
        val fetched = result.getOrNull()
        if (fetched != null && fetched.id != request.login.userId) {
            markVerificationFailed(request)
            return
        }

        if (fetched == null || !fetched.isActive) {
            // Do not leave a deleted login on a cached Ready route, even if
            // cleanup/sign-out takes time or fails. External cleanup mutation
            // boundaries still need their own owner fence (A4/S1).
            snapshot.value = snapshot.value.copy(
                profile = null, revoking = true, revalidating = false,
            )
            tokenJob?.cancel()
            if (!owns(request)) return
            _messages.tryEmit(
                if (fetched == null) "Your account is no longer active. Sign in again."
                else "This account was deleted. Contact support to restore it.",
            )
            if (!owns(request)) return
            signOutCleanup.wipeLocalUserState()
            if (!owns(request)) return
            try {
                authRepository.signOut()
            } catch (ce: CancellationException) {
                throw ce
            } catch (_: Exception) {
                // The deleted account stays behind the loading gate.
            }
            return
        }

        val gate = ProfileGate(
            role = fetched.takeIf { it.roleConfirmed }
                ?.let { it.activeRoleKey ?: it.rawRoleKey }?.takeUnless { it.isBlank() },
            onboarded = fetched.hasCompletedV2Onboarding,
            baseDone = !fetched.phone.isNullOrBlank() &&
                !fetched.state.isNullOrBlank() && !fetched.district.isNullOrBlank(),
        )
        try {
            preferenceWrites.withLock {
                if (!owns(request)) return@withLock
                if (gate.role == null) userPrefs.clearActiveRole()
                else userPrefs.setActiveRole(gate.role)
                if (!owns(request)) return@withLock
                userPrefs.setV2OnboardingComplete(gate.onboarded)
                if (!owns(request)) return@withLock
                // SecurePrefs can emit role before its DataStore edit returns.
                // Publish the root gate only after both owned writes finish.
                snapshot.value = snapshot.value.copy(profile = gate, revalidating = false)
            }
        } catch (ce: CancellationException) {
            throw ce
        } catch (_: Exception) {
            // Initial fetch stays Loading; a later manual refresh may retry.
            markVerificationFailed(request)
        }
    }

    private fun markVerificationFailed(request: Request) {
        if (latestRequest == request && snapshot.value.login == request.login) {
            snapshot.value = snapshot.value.copy(verificationFailed = true)
        }
    }
}

data class SessionOwner(val userId: String, val generation: Long)

data class SessionPresentation(
    val state: SessionState = SessionState.Loading,
    val owner: SessionOwner? = null,
    val validatedRole: UserRole? = null,
    val profileValidated: Boolean = false,
    val resolvingAuth: Boolean = true,
    val verificationFailed: Boolean = false,
)

sealed interface SessionState {
    data object Loading : SessionState
    data object SignedOut : SessionState
    data class NeedsRole(val userId: String, val email: String?) : SessionState
    data class NeedsOnboarding(
        val userId: String,
        val email: String?,
        val role: String,
    ) : SessionState
    data class Ready(val userId: String, val email: String?, val role: String) : SessionState
}
