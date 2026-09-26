package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.SignOutCleanup
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.profile.ProfileInvalidations
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
 * Successful role mutations invalidate this gate independently of child screen
 * lifetime; onboarding callbacks use [refreshAfterProfileSave]. Preference
 * writes alone never advance navigation. Opaque writers remain A4 work.
 */
@HiltViewModel
class SessionViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
    private val deviceTokenRegistrar: DeviceTokenRegistrar,
    private val signOutCleanup: SignOutCleanup,
    private val profileInvalidations: ProfileInvalidations = ProfileInvalidations(),
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
        val lastSignedIn: AuthSession.SignedIn? = null,
        val profileLoading: Boolean = false,
        val profileFailed: Boolean = false,
        val signingOut: Boolean = false,
    )

    private val snapshot = MutableStateFlow(Snapshot())
    private var loginGeneration = 0L
    private var fetchRevision = 0L
    private var latestRequest: ProfileRequest? = null
    private var profileJob: Job? = null
    private var tokenJob: Job? = null
    private var signedOutPrefsJob: Job? = null
    private var explicitSignOutJob: Job? = null
    private var pendingProfileRefresh = false
    private val preferenceWrites = Mutex()
    private var observedProfileRevision = profileInvalidations.revision.value

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

    private fun gate(current: Snapshot, session: AuthSession = current.session): SessionState =
        when (session) {
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

    val state: StateFlow<SessionState> = snapshot.map { gate(it) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, SessionState.Loading)

    val presentation: StateFlow<SessionPresentation> = snapshot.map { current ->
        val resolving = current.session == AuthSession.Unknown
        SessionPresentation(
            state = gate(current),
            owner = current.login?.let { SessionOwner(it.userId, it.generation) },
            baseProfileComplete = current.profile?.baseDone == true,
            retainedState = if (resolving) current.lastSignedIn?.let { gate(current, it) }
                ?.takeUnless { it == SessionState.Loading } else null,
            resolvingAuth = resolving,
            profileLoading = current.profileLoading,
            profileFailed = current.profileFailed,
            signingOut = current.signingOut,
        )
    }.stateIn(viewModelScope, SharingStarted.Eagerly, SessionPresentation(resolvingAuth = true))

    // Keep init after every state field: Main.immediate may collect immediately
    // during construction, including when dependencies finish synchronously.
    init {
        viewModelScope.launch {
            // Never suspend this collector on token, profile, or preference I/O.
            // Cancel-and-join/collectLatest can block a new login behind an old
            // dependency that swallows cancellation. Ownership is the backstop.
            authRepository.sessionState.collect { session -> observeSession(session) }
        }
        viewModelScope.launch {
            profileInvalidations.revision.collect { revision ->
                if (revision != observedProfileRevision) {
                    observedProfileRevision = revision
                    refreshAfterInvalidation(discardGate = false)
                }
            }
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
                    snapshot.value = previous.copy(session = session, lastSignedIn = session)
                    if (pendingProfileRefresh && !previous.revoking) {
                        pendingProfileRefresh = false
                        startProfileRequest(checkNotNull(previous.login))
                    }
                } else {
                    val login = Login(session.userId, ++loginGeneration)
                    // Establish the loading fence and discard A's entire gate
                    // before any suspending work for B is launched.
                    snapshot.value = Snapshot(session = session, login = login, lastSignedIn = session)
                    cancelLoginWork()
                    pendingProfileRefresh = false
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
        explicitSignOutJob?.cancel()
        pendingProfileRefresh = false
    }

    private suspend fun isCurrentSignOut(generation: Long): Boolean {
        val live = authRepository.sessionState.first()
        currentCoroutineContext().ensureActive()
        return loginGeneration == generation && snapshot.value.session == AuthSession.SignedOut &&
            live == AuthSession.SignedOut
    }

    /**
     * Called on foreground. A refresh failure
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

    /** A confirmed mutation makes the old gate obsolete; failed re-fetch stays gated. */
    fun refreshAfterProfileSave(owner: SessionOwner? = presentation.value.owner) {
        viewModelScope.launch {
            if (mayActFromUi(owner)) refreshAfterInvalidation(discardGate = true)
        }
    }

    private fun ownsPresentation(owner: SessionOwner?): Boolean {
        val current = snapshot.value
        if (current.session !is AuthSession.SignedIn) return false
        val login = current.login ?: return false
        return owner != null && owner.userId == login.userId && owner.generation == login.generation
    }

    /** Unlike background bootstrap, UI actions never wait for a future login/Unknown resolution. */
    private suspend fun mayActFromUi(owner: SessionOwner?): Boolean {
        if (!ownsPresentation(owner)) return false
        val live = authRepository.sessionState.first()
        currentCoroutineContext().ensureActive()
        return live is AuthSession.SignedIn && live.userId == owner?.userId && ownsPresentation(owner)
    }

    /** A global notification carries no owner: it may refresh B, never destroy B's form. */
    private fun refreshAfterInvalidation(discardGate: Boolean) {
        val current = snapshot.value
        if (current.login == null || current.revoking) return
        latestRequest = null
        profileJob?.cancel()
        snapshot.value = current.copy(
            profile = if (discardGate) null else current.profile,
            profileFailed = false,
            profileLoading = false,
        )
        pendingProfileRefresh = true
        if (current.session is AuthSession.SignedIn) {
            pendingProfileRefresh = false
            startProfileRequest(current.login)
        }
    }

    /** Reachable exit from setup/recovery; opaque cleanup internals remain the A12 boundary. */
    fun signOutFromGate(owner: SessionOwner? = presentation.value.owner) {
        if (!ownsPresentation(owner)) return
        if (snapshot.value.signingOut || explicitSignOutJob?.isActive == true) return
        explicitSignOutJob = viewModelScope.launch {
            if (!mayActFromUi(owner)) return@launch
            val current = snapshot.value
            val login = current.login ?: return@launch
            profileJob?.cancel()
            tokenJob?.cancel()
            latestRequest = null
            snapshot.value = current.copy(profile = null, revoking = true, profileLoading = false, signingOut = true)
            try {
                if (!isLiveLogin(login)) return@launch
                signOutCleanup.wipeLocalUserState()
                if (!isLiveLogin(login)) return@launch
                authRepository.signOut().getOrThrow()
            } catch (ce: CancellationException) {
                // A dependency can return cancellation while this VM is still
                // alive. Release only this login's progress UI for retry.
                if (snapshot.value.login == login) {
                    snapshot.value = snapshot.value.copy(revoking = false, profileFailed = true, signingOut = false)
                }
                throw ce
            } catch (_: Exception) {
                if (isLiveLogin(login)) {
                    snapshot.value = snapshot.value.copy(revoking = false, profileFailed = true, signingOut = false)
                    _messages.tryEmit("Couldn't sign out. Please try again.")
                }
            }
        }
    }

    private fun startProfileRequest(login: Login) {
        val request = ProfileRequest(login, ++fetchRevision)
        latestRequest = request
        profileJob?.cancel()
        snapshot.value = snapshot.value.copy(profileLoading = true, profileFailed = false)
        profileJob = viewModelScope.launch {
            try {
                bootstrapProfile(request)
            } finally {
                // An old request cannot release the new request or its loading
                // fence. Only an owned successful profile resolves that fence.
                if (ownsRequest(request)) {
                    latestRequest = null
                    profileJob = null
                    snapshot.value = snapshot.value.copy(profileLoading = false)
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
        if (result.isFailure) {
            snapshot.value = snapshot.value.copy(profileFailed = true)
            return
        }
        val fetched = result.getOrNull()
        if (fetched != null && fetched.id != request.login.userId) {
            snapshot.value = snapshot.value.copy(profileFailed = true)
            return
        }

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
                snapshot.value = snapshot.value.copy(profile = profile, profileFailed = false)
            }
        } catch (ce: CancellationException) {
            throw ce
        } catch (_: Exception) {
            // Other hosts still read these mirrors directly. Do not promote a
            // new gate after a failed write, or crash Main on storage I/O.
            // Retain the same-login validated gate (initially Loading) and let
            // refreshNow retry the required mirrors and atomic publication.
            if (mayPublish(request)) snapshot.value = snapshot.value.copy(profileFailed = true)
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
