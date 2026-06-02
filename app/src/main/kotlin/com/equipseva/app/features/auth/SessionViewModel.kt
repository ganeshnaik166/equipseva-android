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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Top-level session state used by the root nav graph to gate AUTH vs MAIN.
 *
 * Source-of-truth ordering for role:
 *  1. `profiles.role_confirmed = true` on the server (synced into local prefs on sign-in).
 *  2. Local pref written during a confirmed RoleSelect on this device.
 *
 * If neither holds, the user lands on RoleSelect.
 */
@HiltViewModel
class SessionViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
    private val deviceTokenRegistrar: DeviceTokenRegistrar,
    private val signOutCleanup: SignOutCleanup,
) : ViewModel() {

    private val bootstrapping = MutableStateFlow(false)

    /** One-shot toasts surfaced by the sign-in gate (e.g. "Account deleted").
     *  SharedFlow(replay = 0) so a toast emitted while AppNavGraph is not
     *  collecting (process death, screen torn down) drops on the floor
     *  instead of firing the next time the collector mounts — otherwise
     *  "Your account is no longer active" could phantom-toast on a fresh
     *  cold start unrelated to the original deletion. */
    private val _messages = kotlinx.coroutines.flow.MutableSharedFlow<String>(
        extraBufferCapacity = 4,
    )
    val messages: kotlinx.coroutines.flow.Flow<String> = _messages

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { signedIn ->
                    // Re-register FCM token under the new user id. onNewToken
                    // only fires on actual token rotation, so a returning
                    // user signing in on a device whose previous session
                    // was revoke()'d would otherwise have no row in
                    // device_tokens and receive zero pushes. Best-effort.
                    // Round 431 — runCatching also catches CancellationException,
                    // which would silently break scope cancellation when the
                    // viewmodel tears down. Explicit try/catch with rethrow.
                    try {
                        deviceTokenRegistrar.refresh()
                    } catch (ce: CancellationException) {
                        throw ce
                    } catch (_: Throwable) {
                        // Best-effort token refresh; ignore non-cancellation
                        // failures (network, Play Services missing).
                    }
                    bootstrapProfile(signedIn.userId)
                }
        }
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                if (session is AuthSession.SignedOut) {
                    userPrefs.clearActiveRole()
                    bootstrapping.value = false
                    // Reset in-memory onboarding state; SignOutCleanup
                    // wipes the persisted sticky cache as well so the
                    // next user signing in on this device doesn't
                    // inherit the previous user's "onboarded" status.
                    profileOnboardingV2Complete.value = null
                    _profileBaseV2Done.value = false
                }
            }
        }
    }

    /**
     * Re-fetch the profile for the current session. Called from
     * AppNavGraph on subsequent ON_RESUME events so a server-side role
     * change, hard-delete, or soft-delete that happened while the app
     * was backgrounded is reflected on the next foreground without
     * waiting for a sign-out/sign-in. No-op when there's no active
     * session — the sessionState collector handles wiring on next
     * sign-in.
     */
    fun refreshNow() {
        viewModelScope.launch {
            val session = authRepository.sessionState.first() as? AuthSession.SignedIn
                ?: return@launch
            bootstrapProfile(session.userId)
        }
    }

    val tourSeen: StateFlow<Boolean> = userPrefs.observeTourSeen().stateIn(
        scope = viewModelScope,
        // Eagerly so the upstream stays alive across app background → foreground.
        // WhileSubscribed(5_000) caused the StateFlow to cold-restart at the
        // initialValue after >5s in background, which triggered AppNavGraph's
        // Loading branch and unmounted the entire NavHost on every resume.
        started = SharingStarted.Eagerly,
        initialValue = true, // assume seen until first emission so we don't flash the tour on splash
    )

    /**
     * v0.2.0 onboarding state for the signed-in user — null until the
     * first profile fetch resolves. The combine treats null as "use the
     * sticky [UserPrefs.v2OnboardingComplete] cache for the fast-path";
     * once resolved, this flow is the ground truth.
     */
    private val profileOnboardingV2Complete = MutableStateFlow<Boolean?>(null)

    /**
     * Round 425 sub-step indicator. The v0.2.0 base fields (phone /
     * state / district) being filled even when [profileOnboardingV2Complete]
     * is false means the user has cleared step 1 (HospitalOnboardingScreen
     * / EngineerOnboardingScreen) but failed the engineer-only payout-
     * methods gate. The onboarding host reads this to decide which screen
     * to mount for an engineer: false → step 1 (v0.2.0), true → step 2
     * (payout). For hospitals this flag mirrors [profileOnboardingV2Complete]
     * because the payout gate doesn't apply to them.
     */
    private val _profileBaseV2Done = MutableStateFlow(false)
    val profileBaseV2Done: StateFlow<Boolean> = _profileBaseV2Done

    val state: StateFlow<SessionState> =
        combine(
            authRepository.sessionState,
            userPrefs.activeRole,
            bootstrapping,
            profileOnboardingV2Complete,
            userPrefs.v2OnboardingComplete,
        ) { session, role, syncing, fetchedOnboarding, cachedOnboarding ->
            when (session) {
                is AuthSession.Unknown -> SessionState.Loading
                is AuthSession.SignedOut -> SessionState.SignedOut
                is AuthSession.SignedIn -> when {
                    role.isNullOrBlank() && syncing -> SessionState.Loading
                    role.isNullOrBlank() -> SessionState.NeedsRole(session.userId, session.email)
                    else -> {
                        // Prefer the fresh server-side value over the cache.
                        // The cache is sticky-true so it never demotes the
                        // server's truth — it only short-circuits the splash
                        // for users we've already seen onboarded.
                        val onboarded = fetchedOnboarding ?: cachedOnboarding
                        if (onboarded) {
                            SessionState.Ready(session.userId, session.email, role)
                        } else {
                            SessionState.NeedsOnboarding(session.userId, session.email, role)
                        }
                    }
                }
            }
        }.stateIn(
            scope = viewModelScope,
            // Eagerly: the upstream session subscription must survive
            // background → foreground transitions. With WhileSubscribed(5_000)
            // the StateFlow cold-restarted at `Loading` on every resume after
            // 5s+, which mounted SplashScreen() in AppNavGraph and tore down
            // the entire NavHost — wiping in-flight forms and the back stack.
            started = SharingStarted.Eagerly,
            initialValue = SessionState.Loading,
        )

    private suspend fun bootstrapProfile(userId: String) {
        // Always fetch the profile, even when a role is cached locally. The
        // previous fast-path skip caused a "zombie session" — when an admin
        // hard-deleted a user server-side, the cached role kept the app on
        // Home with stale data forever instead of bouncing to Welcome.
        val cached = userPrefs.activeRole.first()
        bootstrapping.value = cached.isNullOrBlank()
        try {
            val result = profileRepository.fetchById(userId)
            val fetched = result.getOrNull()
            // Server-deleted account: row is gone (success(null)) while
            // Supabase still hands us a session token. Sign out + tell the
            // user. Distinct from network failure (Result.failure) where we
            // keep the cached session.
            if (result.isSuccess && fetched == null) {
                _messages.tryEmit("Your account is no longer active. Sign in again.")
                // Run the full local-state wipe (outbox, FCM token,
                // DataStore prefs, realtime channels, …) before
                // dropping the auth session. Previously only
                // clearActiveRole() was called, so the zombie path
                // left the previous user's outbox + FCM token + chat
                // mutes hanging around for whoever signed in next on
                // the same device.
                signOutCleanup.wipeLocalUserState()
                // Round 431 — explicit try/catch so CancellationException
                // surfaces and aborts the coroutine cleanly. runCatching
                // would swallow it and the calling launch would continue
                // through the `return` below as if everything succeeded.
                try {
                    authRepository.signOut()
                } catch (ce: CancellationException) {
                    throw ce
                } catch (_: Throwable) {
                    // signOut is best-effort here; even if it fails the
                    // local-state wipe already ran.
                }
                return
            }
            // Defense-in-depth gate: legacy soft-delete (is_active=false)
            // ships us a row but flags it inactive. Hard delete normally
            // removes the row entirely (handled above).
            if (fetched != null && !fetched.isActive) {
                _messages.tryEmit("This account was deleted. Contact support to restore it.")
                signOutCleanup.wipeLocalUserState()
                try {
                    authRepository.signOut()
                } catch (ce: CancellationException) {
                    throw ce
                } catch (_: Throwable) {
                    // Best-effort; see above.
                }
                return
            }
            // Always overwrite the cached role with the server-confirmed
            // value when present. The previous version only wrote when
            // cached was blank — but on a multi-user device, user A's
            // cached role would survive after user A signed out and user B
            // signed in, dispatching B to A's Hub (hospital → engineer
            // home, etc.). A blank confirmedRole still leaves cached alone
            // so a transient empty fetch doesn't wipe a valid role.
            //
            // Use active_role (multi-role hub) over the scalar role: the
            // handle_new_user trigger hardcodes scalar role='engineer' for
            // every signup as a security guard, so reading rawRoleKey here
            // would dispatch every Hospital signup to the engineer hub.
            val confirmedRole = fetched?.takeIf { it.roleConfirmed }
                ?.let { it.activeRoleKey ?: it.rawRoleKey }
            if (!confirmedRole.isNullOrBlank() && cached != confirmedRole) {
                userPrefs.setActiveRole(confirmedRole)
            }
            // v0.2.0 onboarding gate: surface phone + state + district
            // completeness from the just-fetched profile. We also
            // promote a true result into the sticky [UserPrefs] cache so
            // the next cold start can fast-path past Loading without
            // waiting for this network round-trip.
            if (fetched != null) {
                val onboarded = fetched.hasCompletedV2Onboarding
                profileOnboardingV2Complete.value = onboarded
                if (onboarded) {
                    userPrefs.setV2OnboardingComplete(true)
                }
                // Round 425 — surface whether the base v0.2.0 fields are
                // filled separately from the payout-methods gate so the
                // onboarding host can dispatch to step 1 vs step 2.
                val baseDone = !fetched.phone.isNullOrBlank() &&
                    !fetched.state.isNullOrBlank() &&
                    !fetched.district.isNullOrBlank()
                _profileBaseV2Done.value = baseDone
            }
        } finally {
            bootstrapping.value = false
        }
    }
}

sealed interface SessionState {
    data object Loading : SessionState
    data object SignedOut : SessionState
    data class NeedsRole(val userId: String, val email: String?) : SessionState

    /**
     * v0.2.0 mandatory onboarding pending. Signed-in, role confirmed,
     * but `profiles.hasCompletedV2Onboarding == false` (phone / state /
     * district missing). AppNavGraph routes to ONBOARDING_HOST_ROUTE
     * outside MainNavGraph so Home never flashes; the screen calls
     * [SessionViewModel.refreshNow] after a successful save to flip
     * back to [Ready] cleanly.
     */
    data class NeedsOnboarding(
        val userId: String,
        val email: String?,
        val role: String,
    ) : SessionState

    data class Ready(val userId: String, val email: String?, val role: String) : SessionState
}
