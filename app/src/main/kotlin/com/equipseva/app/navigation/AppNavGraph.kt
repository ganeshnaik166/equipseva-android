package com.equipseva.app.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.equipseva.app.features.auth.SessionState
import com.equipseva.app.features.auth.SessionViewModel
import kotlinx.coroutines.launch

/**
 * Root composable. Always lands on the Global Service Hub when not in the
 * initial Loading splash; the Hub itself dispatches to Auth or Main based
 * on the user's selection. RoleSelectScreen is no longer a forced gate —
 * service picking lives on the Hub.
 */
@Composable
fun AppNavGraph(sessionViewModel: SessionViewModel = hiltViewModel()) {
    val sessionState by sessionViewModel.state.collectAsStateWithLifecycle()
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
                if (rootMountedOnce.value) {
                    RootHost(
                        showSnackbar = showSnackbar,
                        showTour = !tourSeen,
                    )
                } else {
                    SplashScreen()
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
    showSnackbar: (String) -> Unit,
    showTour: Boolean,
    sessionViewModel: SessionViewModel = hiltViewModel(),
) {
    val navController = rememberNavController()
    val sessionState by sessionViewModel.state.collectAsStateWithLifecycle()

    // Cold-start gate: signed-out users land on Welcome, signed-in users
    // land on Home (or the v0.2.0 onboarding gate when phone+state+district
    // aren't on the profile yet). Captured once at first composition so the
    // NavHost's startDestination is stable.
    val coldStartRoute = remember {
        when (sessionState) {
            is SessionState.SignedOut -> Routes.AUTH_GRAPH
            is SessionState.NeedsOnboarding -> ONBOARDING_HOST_ROUTE
            else -> MAIN_HOST_ROUTE
        }
    }

    val navigateToMain: () -> Unit = {
        navController.navigate(MAIN_HOST_ROUTE) {
            popUpTo(0) { inclusive = true }
            launchSingleTop = true
        }
    }

    val navigateToOnboarding: () -> Unit = {
        navController.navigate(ONBOARDING_HOST_ROUTE) {
            popUpTo(0) { inclusive = true }
            launchSingleTop = true
        }
    }

    // Sign-out redirect: when the session transitions authenticated →
    // SignedOut while we're past Welcome, route back to AUTH_GRAPH. Also
    // promote/demote between the onboarding host and the main host as
    // [SessionState.NeedsOnboarding] ↔ [SessionState.Ready] transitions
    // happen — covers the post-onboarding refresh as well as a profile
    // server-side reset spotted on resume.
    val sawAuthenticated = remember { mutableStateOf(false) }
    LaunchedEffect(sessionState) {
        when (val s = sessionState) {
            is SessionState.NeedsRole, is SessionState.Ready, is SessionState.NeedsOnboarding -> {
                sawAuthenticated.value = true
                if (s is SessionState.NeedsOnboarding) {
                    val cur = navController.currentDestination?.route
                    if (cur != ONBOARDING_HOST_ROUTE) navigateToOnboarding()
                } else if (s is SessionState.Ready) {
                    val cur = navController.currentDestination?.route
                    if (cur == ONBOARDING_HOST_ROUTE) navigateToMain()
                }
            }
            is SessionState.SignedOut -> if (sawAuthenticated.value) {
                sawAuthenticated.value = false
                navController.navigate(Routes.AUTH_GRAPH) {
                    popUpTo(0) { inclusive = true }
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
            )
        }
        composable(ONBOARDING_HOST_ROUTE) {
            OnboardingHostInline(
                showSnackbar = showSnackbar,
                onDone = { navigateToMain() },
            )
        }
        composable(MAIN_HOST_ROUTE) {
            MainNavGraph(
                showTour = showTour,
                onSignIn = {
                    navController.navigate(Routes.AUTH_GRAPH) { launchSingleTop = true }
                },
            )
        }
    }
}

private const val MAIN_HOST_ROUTE = "main_host"
private const val ONBOARDING_HOST_ROUTE = "onboarding_host"

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
    sessionViewModel: SessionViewModel = hiltViewModel(),
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
    when (role) {
        com.equipseva.app.features.auth.UserRole.HOSPITAL.storageKey ->
            com.equipseva.app.features.onboarding.HospitalOnboardingScreen(
                onDone = handleDone,
                onShowMessage = showSnackbar,
            )
        // Engineer onboarding lands in PR #1018. Until then engineers
        // never enter NeedsOnboarding (their KYC flow already captures
        // phone, and state/district will be filled by the upcoming
        // engineer-specific screen). If we somehow get here, fall back
        // to the hospital screen rather than mounting a blank surface.
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
    sessionViewModel: SessionViewModel = hiltViewModel(),
) {
    val navController = rememberNavController()
    val sessionState by sessionViewModel.state.collectAsStateWithLifecycle()

    // Only hand off to the main graph after the session *transitions* away
    // from SignedOut (i.e. a fresh sign-in completes). Without this guard a
    // user who is already authenticated server-side but lands here from
    // ProfileScreen's "Sign in" button would be bounced straight back to
    // Home before the Welcome screen ever rendered.
    val sawSignedOut = remember { mutableStateOf(false) }
    LaunchedEffect(sessionState) {
        if (sessionState is SessionState.SignedOut) {
            sawSignedOut.value = true
            return@LaunchedEffect
        }
        val authenticated = sessionState is SessionState.NeedsRole ||
            sessionState is SessionState.Ready ||
            sessionState is SessionState.NeedsOnboarding
        if (authenticated && sawSignedOut.value) {
            onAuthSuccess()
        }
    }

    NavHost(
        navController = navController,
        startDestination = Routes.AUTH_GRAPH,
        modifier = Modifier.fillMaxSize(),
    ) {
        authNavGraph(navController, showSnackbar)
    }
}

@Composable
private fun SplashScreen() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}
