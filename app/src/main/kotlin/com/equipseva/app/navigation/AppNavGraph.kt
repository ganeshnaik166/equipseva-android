package com.equipseva.app.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.equipseva.app.features.auth.SessionState
import com.equipseva.app.features.auth.SessionPresentation
import com.equipseva.app.features.auth.SessionViewModel
import com.equipseva.app.features.auth.UserRole
import kotlinx.coroutines.launch

/**
 * Root composable. Always lands on the Global Service Hub when not in the
 * initial Loading splash; the Hub itself dispatches to Auth or Main based
 * on the user's selection. RoleSelectScreen is no longer a forced gate —
 * service picking lives on the Hub.
 */
@Composable
fun AppNavGraph(sessionViewModel: SessionViewModel = hiltViewModel()) {
    val presentation by sessionViewModel.presentation.collectAsStateWithLifecycle()
    val sessionState = presentation.state
    val snackbarHost = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    val showSnackbar: (String) -> Unit = { msg ->
        scope.launch { snackbarHost.showSnackbar(msg) }
    }

    val tourSeen by sessionViewModel.tourSeen.collectAsStateWithLifecycle()

    LaunchedEffect(sessionViewModel) {
        sessionViewModel.messages.collect { msg -> showSnackbar(msg) }
    }

    // Re-fetch the profile on each foreground except the very first.
    // SessionViewModel.init already calls bootstrapProfile on the
    // sessionState collector; firing again on first ON_RESUME would
    // double-load on cold start (same pattern PR #556 closed for
    // HospitalActiveJobsScreen). Subsequent resumes catch server-side
    // changes (role demotion, hard-delete, ban) that happened while
    // the app was backgrounded.
    var sessionFirstResume by remember { mutableStateOf(true) }
    androidx.lifecycle.compose.LifecycleEventEffect(
        androidx.lifecycle.Lifecycle.Event.ON_RESUME,
    ) {
        if (sessionFirstResume) {
            sessionFirstResume = false
        } else {
            sessionViewModel.refreshNow()
        }
    }

    // RootHost stays mounted across Loading↔SignedIn transitions. Earlier
    // we swapped to SplashScreen on Loading, which DESTROYED the entire
    // navigation back stack every time Supabase briefly re-emitted
    // Initializing on app resume — the user's KYC entry (and any other
    // mid-flow state) was wiped. The splash now overlays only on the very
    // first Loading event, while the host stays alive underneath.
    val rootMountedOnce = remember { mutableStateOf(false) }
    LaunchedEffect(sessionState) {
        if (sessionState !is SessionState.Loading) {
            rootMountedOnce.value = true
        }
    }
    // Snackbar sits at the top of the screen (overlay) instead of the
    // Scaffold's default bottom slot. Top-aligned alerts read as system-style
    // banners rather than competing with bottom-nav and primary CTAs that
    // hug the bottom edge across hospital/engineer/founder surfaces.
    Box(modifier = Modifier.fillMaxSize()) {
        Scaffold { padding ->
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                RootSessionBoundary(
                    presentation = presentation,
                    mountedOnce = rootMountedOnce.value,
                    onRetry = { sessionViewModel.refreshNow() },
                ) {
                    RootHost(
                        presentation = presentation,
                        showSnackbar = showSnackbar,
                        showTour = !tourSeen,
                        sessionViewModel = sessionViewModel,
                    )
                }
            }
        }
        SnackbarHost(
            hostState = snackbarHost,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .statusBarsPadding(),
        )
    }
}

@Composable
private fun RootHost(
    presentation: SessionPresentation,
    showSnackbar: (String) -> Unit,
    showTour: Boolean,
    sessionViewModel: SessionViewModel,
) {
    val navController = rememberNavController()
    val sessionState = presentation.state
    val latestPresentation by rememberUpdatedState(presentation)
    val hostStartedPending = remember { sessionState is SessionState.Loading }
    val hostStartedSignedOut = remember { sessionState is SessionState.SignedOut }

    // Cold-start gate: signed-out users land on Welcome, signed-in users
    // land on Home (or the v0.2.0 onboarding gate when phone+state+district
    // aren't on the profile yet). Captured once at first composition so the
    // NavHost's startDestination is stable.
    val coldStartRoute = remember {
        when (sessionState) {
            is SessionState.SignedOut -> Routes.AUTH_GRAPH
            is SessionState.Loading -> Routes.AUTH_GRAPH
            is SessionState.NeedsRole -> Routes.AUTH_GRAPH
            is SessionState.NeedsOnboarding -> ONBOARDING_HOST_ROUTE
            else -> MAIN_HOST_ROUTE
        }
    }

    val navigateToMain: () -> Unit = {
        val live = sessionViewModel.currentPresentation()
        if (mayNavigateToMain(latestPresentation, live)) {
            navController.navigate(MAIN_HOST_ROUTE) {
                // popUpTo(0) silently no-ops since Compose Navigation 2.9.
                popUpTo(navController.graph.id) { inclusive = true }
                launchSingleTop = true
            }
        }
    }

    val navigateToOnboarding: () -> Unit = {
        val live = sessionViewModel.currentPresentation()
        if (live.owner == latestPresentation.owner &&
            live.validatedRole == latestPresentation.validatedRole &&
            !live.resolvingAuth &&
            live.state is SessionState.NeedsOnboarding
        ) {
            navController.navigate(ONBOARDING_HOST_ROUTE) {
                popUpTo(navController.graph.id) { inclusive = true }
                launchSingleTop = true
            }
        }
    }

    // Sign-out redirect: when the session transitions authenticated →
    // SignedOut while we're past Welcome, route back to AUTH_GRAPH. Also
    // promote/demote between the onboarding host and the main host as
    // [SessionState.NeedsOnboarding] ↔ [SessionState.Ready] transitions
    // happen — covers the post-onboarding refresh as well as a profile
    // server-side reset spotted on resume.
    val sawAuthenticated = remember { mutableStateOf(false) }
    val sawNeedsRole = remember { mutableStateOf(false) }
    LaunchedEffect(sessionState) {
        when (val s = sessionState) {
            is SessionState.NeedsRole -> {
                sawAuthenticated.value = true
                sawNeedsRole.value = true
                if (navController.currentDestination?.route != Routes.AUTH_GRAPH) {
                    navController.navigate(Routes.AUTH_GRAPH) {
                        popUpTo(navController.graph.id) { inclusive = true }
                        launchSingleTop = true
                    }
                }
            }
            is SessionState.Ready, is SessionState.NeedsOnboarding -> {
                sawAuthenticated.value = true
                if (s is SessionState.NeedsOnboarding) {
                    val cur = navController.currentDestination?.route
                    // A SignedOut-started auth host owns signup's hospital
                    // phone gate; its nested route decides when to hand off.
                    if (cur != ONBOARDING_HOST_ROUTE &&
                        !(cur == Routes.AUTH_GRAPH && hostStartedSignedOut)
                    ) navigateToOnboarding()
                } else if (s is SessionState.Ready) {
                    val cur = navController.currentDestination?.route
                    if (cur == ONBOARDING_HOST_ROUTE ||
                        (cur == Routes.AUTH_GRAPH && !hostStartedSignedOut &&
                            (hostStartedPending || sawNeedsRole.value))
                    ) navigateToMain()
                }
            }
            is SessionState.SignedOut -> if (sawAuthenticated.value) {
                sawAuthenticated.value = false
                navController.navigate(Routes.AUTH_GRAPH) {
                    // graph.id, not 0 — see comment on navigateToOnboarding.
                    popUpTo(navController.graph.id) { inclusive = true }
                    launchSingleTop = true
                }
            }
            else -> Unit
        }
    }

    NavHost(
        navController = navController,
        startDestination = coldStartRoute,
        modifier = Modifier.fillMaxSize(),
    ) {
        composable(Routes.AUTH_GRAPH) {
            AuthHostInline(
                showSnackbar = showSnackbar,
                onAuthSuccess = { navigateToMain() },
                onNeedsOnboarding = { navigateToOnboarding() },
                startedSignedOut = hostStartedSignedOut,
                sessionViewModel = sessionViewModel,
            )
        }
        composable(ONBOARDING_HOST_ROUTE) {
            OnboardingHostInline(
                showSnackbar = showSnackbar,
                onDone = { navigateToMain() },
                sessionViewModel = sessionViewModel,
            )
        }
        composable(MAIN_HOST_ROUTE) {
            if (mayComposeMain(latestPresentation, sessionViewModel.currentPresentation())) {
                MainNavGraph(
                    showTour = showTour,
                    validatedRole = latestPresentation.validatedRole,
                    onSignIn = {
                        navController.navigate(Routes.AUTH_GRAPH) { launchSingleTop = true }
                    },
                )
            }
        }
    }
}

private const val MAIN_HOST_ROUTE = "main_host"
private const val ONBOARDING_HOST_ROUTE = "onboarding_host"

/** Fence an old auth/phone callback before it changes the root destination. */
internal fun mayNavigateToMain(
    admitted: SessionPresentation,
    live: SessionPresentation,
): Boolean = admitted.owner != null && admitted.owner == live.owner &&
    admitted.validatedRole != null && admitted.validatedRole == live.validatedRole &&
    !live.resolvingAuth && live.state is SessionState.Ready

internal enum class AuthHandoffDestination { MAIN, ONBOARDING }

/** A newly signed-up hospital must finish its phone step before any private host. */
internal fun authHandoffDestination(
    state: SessionState,
    route: String?,
    phoneDone: Boolean,
): AuthHandoffDestination? {
    val role = when (state) {
        is SessionState.Ready -> state.role
        is SessionState.NeedsOnboarding -> state.role
        else -> return null
    }
    val validatedRole = UserRole.fromKey(role)
    if (validatedRole != UserRole.HOSPITAL && validatedRole != UserRole.ENGINEER) return null
    if (validatedRole == UserRole.HOSPITAL &&
        (route == Routes.AUTH_SIGN_UP ||
            (route == Routes.HOSPITAL_PHONE_ONBOARDING && !phoneDone))
    ) return null
    return if (state is SessionState.Ready) AuthHandoffDestination.MAIN
    else AuthHandoffDestination.ONBOARDING
}

internal fun mayEnterHospitalPhone(state: SessionState): Boolean = when (state) {
    is SessionState.Ready -> UserRole.fromKey(state.role) == UserRole.HOSPITAL
    is SessionState.NeedsOnboarding -> UserRole.fromKey(state.role) == UserRole.HOSPITAL
    else -> false
}

/** Never compose a private Main entry using an unvalidated or different login. */
internal fun mayComposeMain(
    admitted: SessionPresentation,
    live: SessionPresentation,
): Boolean = admitted.owner != null && admitted.owner == live.owner &&
    admitted.validatedRole != null && admitted.validatedRole == live.validatedRole &&
    admitted.profileValidated && live.profileValidated &&
    (admitted.state is SessionState.Ready ||
        (admitted.state is SessionState.Loading && admitted.resolvingAuth)) &&
    (live.state is SessionState.Ready ||
        (live.state is SessionState.Loading && live.resolvingAuth))

/**
 * v0.2.0 mandatory onboarding host. Mounted at the AppNavGraph level
 * (not inside MainNavGraph) so Home never flashes for users who land
 * here from [SessionState.NeedsOnboarding]. Dispatches to the right
 * onboarding screen based on the active role; on a successful save the
 * SessionViewModel re-resolves the profile and flips state to Ready,
 * which AppNavGraph promotes to [MAIN_HOST_ROUTE].
 */
@Composable
private fun OnboardingHostInline(
    showSnackbar: (String) -> Unit,
    onDone: () -> Unit,
    sessionViewModel: SessionViewModel,
) {
    val sessionState by sessionViewModel.state.collectAsStateWithLifecycle()
    val role = (sessionState as? SessionState.NeedsOnboarding)?.role
        ?: (sessionState as? SessionState.Ready)?.role
    val handleDone: () -> Unit = {
        // Refresh first; once the profile re-fetch resolves with
        // hasCompletedV2Onboarding=true the session state flips to
        // Ready and the AppNavGraph LaunchedEffect handles the
        // navigation. The explicit onDone() is a belt-and-braces
        // fallback for the rare case where the screen emits Done
        // before the refresh propagates (e.g. test fakes).
        sessionViewModel.refreshNow()
        onDone()
    }
    val baseV2Done by sessionViewModel.profileBaseV2Done.collectAsStateWithLifecycle()
    when (role) {
        com.equipseva.app.features.auth.UserRole.ENGINEER.storageKey ->
            if (baseV2Done) {
                // Step 2 — engineer cleared phone/state/district but
                // still lacks UPI + bank payout methods (round 425).
                com.equipseva.app.features.onboarding.EngineerPayoutOnboardingScreen(
                    onDone = handleDone,
                    onShowMessage = showSnackbar,
                )
            } else {
                com.equipseva.app.features.onboarding.EngineerOnboardingScreen(
                    onDone = handleDone,
                    onShowMessage = showSnackbar,
                )
            }
        // Hospital path (default). Other roles (founder / buyer) shouldn't
        // hit this surface today because the v2 fields aren't required
        // for them, but if they do we fall back to the hospital screen
        // rather than mounting a blank surface.
        else ->
            com.equipseva.app.features.onboarding.HospitalOnboardingScreen(
                onDone = handleDone,
                onShowMessage = showSnackbar,
            )
    }
}

@Composable
private fun AuthHostInline(
    showSnackbar: (String) -> Unit,
    onAuthSuccess: () -> Unit,
    onNeedsOnboarding: () -> Unit,
    startedSignedOut: Boolean,
    sessionViewModel: SessionViewModel,
) {
    val navController = rememberNavController()
    val presentation by sessionViewModel.presentation.collectAsStateWithLifecycle()
    val latestPresentation by rememberUpdatedState(presentation)
    val sessionState = presentation.state

    // Only hand off to the main graph after the session *transitions* away
    // from SignedOut (i.e. a fresh sign-in completes). Without this guard a
    // user who is already authenticated server-side but lands here from
    // ProfileScreen's "Sign in" button would be bounced straight back to
    // Home before the Welcome screen ever rendered.
    val sawSignedOut = remember { mutableStateOf(startedSignedOut) }
    val phoneRequested = remember { mutableStateOf(false) }
    val phoneDone = remember { mutableStateOf(false) }
    val currentRoute by navController.currentBackStackEntryAsState()
    LaunchedEffect(presentation, currentRoute, phoneRequested.value, phoneDone.value) {
        if (sessionState is SessionState.SignedOut) {
            sawSignedOut.value = true
            phoneRequested.value = false
            phoneDone.value = false
            return@LaunchedEffect
        }
        val live = sessionViewModel.currentPresentation()
        if (!sawSignedOut.value || presentation.resolvingAuth ||
            live.owner != presentation.owner || live.resolvingAuth
        ) return@LaunchedEffect
        val route = currentRoute?.destination?.route
        if (phoneRequested.value && route == Routes.AUTH_SIGN_UP &&
            mayEnterHospitalPhone(sessionState)
        ) {
            navController.navigate(Routes.HOSPITAL_PHONE_ONBOARDING) { launchSingleTop = true }
            return@LaunchedEffect
        }
        when (authHandoffDestination(sessionState, route, phoneDone.value)) {
            AuthHandoffDestination.MAIN -> onAuthSuccess()
            AuthHandoffDestination.ONBOARDING -> onNeedsOnboarding()
            null -> Unit
        }
    }

    NavHost(
        navController = navController,
        startDestination = Routes.AUTH_GRAPH,
        modifier = Modifier.fillMaxSize(),
    ) {
        authNavGraph(
            navController = navController,
            showSnackbar = showSnackbar,
            onHospitalPhoneRequested = {
                val live = sessionViewModel.currentPresentation()
                if (navController.currentDestination?.route == Routes.AUTH_SIGN_UP &&
                    live.owner != null &&
                    (latestPresentation.owner == null || latestPresentation.owner == live.owner)
                ) {
                    phoneRequested.value = true
                    sessionViewModel.refreshNow()
                }
            },
            onHospitalPhoneDone = {
                val live = sessionViewModel.currentPresentation()
                if (navController.currentDestination?.route == Routes.HOSPITAL_PHONE_ONBOARDING &&
                    latestPresentation.owner != null && latestPresentation.owner == live.owner
                ) {
                    sessionViewModel.refreshNow()
                    phoneDone.value = true
                }
            },
            onSignUpProfileCommitted = {
                val live = sessionViewModel.currentPresentation()
                if (navController.currentDestination?.route == Routes.AUTH_SIGN_UP &&
                    live.owner != null &&
                    (latestPresentation.owner == null || latestPresentation.owner == live.owner)
                ) sessionViewModel.refreshNow()
            },
        )
    }
}
