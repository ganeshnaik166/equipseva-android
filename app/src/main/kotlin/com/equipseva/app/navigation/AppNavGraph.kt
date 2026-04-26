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
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.features.auth.SessionState
import com.equipseva.app.features.auth.SessionViewModel
import com.equipseva.app.features.hub.GlobalHubScreen
import com.equipseva.app.features.hub.ServiceSelection
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope

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
    postAuthRoleGranter: PostAuthRoleGranter = hiltViewModel(),
) {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = Routes.GLOBAL_HUB,
        modifier = Modifier.fillMaxSize(),
    ) {
        composable(Routes.GLOBAL_HUB) {
            GlobalHubScreen(
                onAuthRequired = {
                    // Selection already stashed in ServiceSelection by the VM.
                    navController.navigate(Routes.AUTH_GRAPH)
                },
                onLandOnMain = {
                    navController.navigate(MAIN_HOST_ROUTE) {
                        popUpTo(Routes.GLOBAL_HUB) { inclusive = false }
                        launchSingleTop = true
                    }
                },
                onOpenFounder = {
                    navController.navigate(MAIN_HOST_ROUTE) {
                        popUpTo(Routes.GLOBAL_HUB) { inclusive = false }
                        launchSingleTop = true
                    }
                    // Founder dashboard sits inside Main; deep-link via intent
                    // semantics is overkill here — Profile row reaches it.
                },
            )
        }
        composable(Routes.AUTH_GRAPH) {
            AuthHostInline(
                showSnackbar = showSnackbar,
                onAuthSuccess = {
                    val pending = ServiceSelection.consume()
                    if (!pending.isNullOrBlank()) {
                        postAuthRoleGranter.grantAndLand(pending) {
                            navController.navigate(MAIN_HOST_ROUTE) {
                                popUpTo(Routes.GLOBAL_HUB) { inclusive = false }
                                launchSingleTop = true
                            }
                        }
                    } else {
                        navController.navigate(MAIN_HOST_ROUTE) {
                            popUpTo(Routes.GLOBAL_HUB) { inclusive = false }
                            launchSingleTop = true
                        }
                    }
                },
            )
        }
        composable(MAIN_HOST_ROUTE) {
            MainNavGraph(
                showTour = showTour,
                onSwitchService = {
                    // Pop back to the Hub. We rely on popUpTo to clear Main
                    // off the stack so a second pick rebuilds Main fresh.
                    navController.popBackStack(Routes.GLOBAL_HUB, inclusive = false)
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

/**
 * Tiny VM whose sole job is to call `add_role` after auth completes with the
 * service the user picked on the Hub. Lives at root so we don't tear it down
 * mid-RPC if AuthGraph leaves the back stack.
 */
@HiltViewModel
class PostAuthRoleGranter @Inject constructor(
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {
    fun grantAndLand(roleKey: String, onDone: () -> Unit) {
        viewModelScope.launch {
            profileRepository.addRole(roleKey)
                .onSuccess { userPrefs.setActiveRole(roleKey) }
            // Either way, land on Main — the Hub fallback bottom-nav covers
            // the case where the RPC failed (rare; user can re-pick from Profile).
            onDone()
        }
    }
}

@Composable
private fun SplashScreen() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}
