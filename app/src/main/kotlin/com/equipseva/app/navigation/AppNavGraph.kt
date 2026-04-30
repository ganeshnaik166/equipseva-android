package com.equipseva.app.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
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
    Scaffold(snackbarHost = { SnackbarHost(snackbarHost) }) { padding ->
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
    // land on Home. Captured once at first composition (after the Splash
    // resolved Loading) so the NavHost's startDestination is stable.
    val coldStartRoute = remember {
        if (sessionState is SessionState.SignedOut) Routes.AUTH_GRAPH else MAIN_HOST_ROUTE
    }

    val navigateToMain: () -> Unit = {
        navController.navigate(MAIN_HOST_ROUTE) {
            popUpTo(0) { inclusive = true }
            launchSingleTop = true
        }
    }

    // Sign-out redirect: when the session transitions authenticated → SignedOut
    // while we're on MAIN_HOST_ROUTE, route the user to Welcome (AUTH_GRAPH).
    val sawAuthenticated = remember { mutableStateOf(false) }
    LaunchedEffect(sessionState) {
        when {
            sessionState is SessionState.NeedsRole || sessionState is SessionState.Ready -> {
                sawAuthenticated.value = true
            }
            sessionState is SessionState.SignedOut && sawAuthenticated.value -> {
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
            sessionState is SessionState.Ready
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
