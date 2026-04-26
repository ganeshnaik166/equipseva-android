package com.equipseva.app.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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

    Scaffold(snackbarHost = { SnackbarHost(snackbarHost) }) { _ ->
        when (sessionState) {
            SessionState.Loading -> SplashScreen()
            else -> RootHost(
                showSnackbar = showSnackbar,
                showTour = !tourSeen,
            )
        }
    }
}

@Composable
private fun RootHost(
    showSnackbar: (String) -> Unit,
    showTour: Boolean,
) {
    val navController = rememberNavController()

    val navigateToMain: () -> Unit = {
        navController.navigate(MAIN_HOST_ROUTE) {
            popUpTo(MAIN_HOST_ROUTE) { inclusive = true }
            launchSingleTop = true
        }
    }

    // v1: cold-start lands on the 3-card Home Hub (rendered as Routes.HOME
    // inside MainNavGraph). Auth opens as a separate composable when the
    // user taps Sign in.
    NavHost(
        navController = navController,
        startDestination = MAIN_HOST_ROUTE,
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

    // Watch for sign-in completion. AuthGraph itself doesn't navigate
    // anywhere — once SessionState flips off SignedOut, we hand off to the
    // root graph's onAuthSuccess so it can grant the pending role.
    LaunchedEffect(sessionState) {
        when (sessionState) {
            is SessionState.NeedsRole, is SessionState.Ready -> onAuthSuccess()
            else -> Unit
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
