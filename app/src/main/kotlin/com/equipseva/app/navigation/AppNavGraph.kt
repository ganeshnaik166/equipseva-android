package com.equipseva.app.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.rememberNavController
import com.equipseva.app.R
import com.equipseva.app.features.auth.RoleSelectScreen
import com.equipseva.app.features.auth.SessionViewModel
import com.equipseva.app.features.auth.UserRole
import kotlinx.coroutines.launch

/** One root session authority; child completion callbacks request a server refresh only. */
@Composable
internal fun AppNavGraph(
    sessionViewModel: SessionViewModel = hiltViewModel(),
    slots: RootSessionSlots? = null,
) {
    val presentation by sessionViewModel.presentation.collectAsStateWithLifecycle()
    val tourSeen by sessionViewModel.tourSeen.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val showSnackbar: (String) -> Unit = { message -> scope.launch { snackbarHost.showSnackbar(message) } }
    LaunchedEffect(sessionViewModel) {
        sessionViewModel.messages.collect { showSnackbar(it) }
    }

    var firstResume by remember { mutableStateOf(true) }
    androidx.lifecycle.compose.LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
        if (firstResume) firstResume = false else sessionViewModel.refreshNow()
    }

    val content = slots ?: RootSessionSlots(
        auth = { onProfileSaved -> AuthHostInline(showSnackbar, onProfileSaved) },
        role = { onRoleSaved, onSignOut ->
            RoleSelectScreen(onShowMessage = showSnackbar, onRoleSaved = onRoleSaved, onSignOut = onSignOut)
        },
        onboarding = { role, baseDone, onSaved ->
            OnboardingHostInline(role, baseDone, showSnackbar, onSaved)
        },
        main = { role, onProfileSaved ->
            MainNavGraph(showTour = !tourSeen, validatedRole = role, onProfileSaved = onProfileSaved)
        },
        pending = { retry, signOut ->
            SessionRecoveryScreen(
                loading = presentation.profileLoading,
                signingOut = presentation.signingOut,
                canSignOut = presentation.owner != null,
                onRetry = retry,
                onSignOut = signOut,
            )
        },
        resolving = { SessionResolvingScreen() },
    )
    Box(Modifier.fillMaxSize()) {
        Scaffold { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                RootSessionHost(
                    presentation = presentation,
                    onRefresh = sessionViewModel::refreshAfterProfileSave,
                    onSignOut = sessionViewModel::signOutFromGate,
                    slots = content,
                )
            }
        }
        SnackbarHost(snackbarHost, Modifier.align(Alignment.TopCenter).statusBarsPadding())
    }
}

@Composable
private fun OnboardingHostInline(
    role: UserRole,
    baseDone: Boolean,
    showSnackbar: (String) -> Unit,
    onSaved: () -> Unit,
) {
    when (role) {
        UserRole.ENGINEER -> if (baseDone) {
            com.equipseva.app.features.onboarding.EngineerPayoutOnboardingScreen(
                onDone = onSaved, onShowMessage = showSnackbar,
            )
        } else {
            com.equipseva.app.features.onboarding.EngineerOnboardingScreen(
                onDone = onSaved, onShowMessage = showSnackbar,
            )
        }
        UserRole.HOSPITAL -> com.equipseva.app.features.onboarding.HospitalOnboardingScreen(
            onDone = onSaved, onShowMessage = showSnackbar,
        )
        else -> Unit // Root admission excludes deferred/unknown roles.
    }
}

@Composable
private fun AuthHostInline(showSnackbar: (String) -> Unit, onProfileSaved: () -> Unit) {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = Routes.AUTH_GRAPH) {
        authNavGraph(navController, showSnackbar, onProfileSaved)
    }
}

@Composable
internal fun SessionRecoveryScreen(
    loading: Boolean,
    signingOut: Boolean,
    canSignOut: Boolean,
    onRetry: () -> Unit,
    onSignOut: () -> Unit,
) {
    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            if (loading || signingOut) CircularProgressIndicator()
            Text(stringResource(when {
                signingOut -> R.string.root_session_signing_out
                loading -> R.string.root_session_preparing
                else -> R.string.root_session_retry_message
            }))
            Button(onClick = onRetry, enabled = !loading && !signingOut) { Text(stringResource(R.string.root_session_retry)) }
            if (canSignOut) TextButton(onClick = onSignOut, enabled = !signingOut) { Text(stringResource(R.string.root_session_sign_out)) }
        }
    }
}

@Composable
private fun SessionResolvingScreen() {
    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            CircularProgressIndicator()
            Text(stringResource(R.string.root_session_checking))
        }
    }
}
