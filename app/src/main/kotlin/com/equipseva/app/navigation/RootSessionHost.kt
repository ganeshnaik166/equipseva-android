package com.equipseva.app.navigation

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.equipseva.app.features.auth.SessionPresentation
import com.equipseva.app.features.auth.SessionOwner
import com.equipseva.app.features.auth.SessionState
import com.equipseva.app.features.auth.UserRole

/** Inert slots let JVM tests exercise this production navigation/lifetime boundary. */
internal data class RootSessionSlots(
    val auth: @Composable (onProfileSaved: () -> Unit) -> Unit,
    val role: @Composable (onRoleSaved: () -> Unit, onSignOut: () -> Unit) -> Unit,
    val onboarding: @Composable (role: UserRole, baseDone: Boolean, onSaved: () -> Unit) -> Unit,
    val main: @Composable (role: UserRole, onProfileSaved: () -> Unit) -> Unit,
    val pending: @Composable (onRetry: () -> Unit, onSignOut: () -> Unit) -> Unit,
    val resolving: @Composable () -> Unit,
)

internal enum class RootGate { AUTH, ROLE, ONBOARDING, MAIN, PENDING }

internal data class RootDestination(
    val gate: RootGate,
    val owner: String,
    val role: UserRole? = null,
) {
    val pattern: String get() = when (gate) {
        RootGate.AUTH -> "root_auth"
        RootGate.ROLE -> "root_role/{owner}"
        RootGate.ONBOARDING -> "root_onboarding/{owner}/{role}"
        RootGate.MAIN -> "root_main/{owner}/{role}"
        RootGate.PENDING -> "root_pending/{owner}"
    }
    val route: String get() = pattern.replace("{owner}", Uri.encode(owner))
        .replace("{role}", role?.storageKey.orEmpty())

    fun matches(entry: NavBackStackEntry): Boolean = entry.destination.route == pattern &&
        (gate == RootGate.AUTH || entry.arguments?.getString("owner") == owner) &&
        (role == null || entry.arguments?.getString("role") == role.storageKey)
}

internal fun rootDestination(presentation: SessionPresentation): RootDestination {
    val owner = presentation.owner
    val key = owner?.let { "${it.userId}:${it.generation}" } ?: "none"
    val state = if (presentation.resolvingAuth && presentation.state == SessionState.Loading) {
        presentation.retainedState ?: SessionState.Loading
    } else presentation.state
    if (state == SessionState.SignedOut) return RootDestination(RootGate.AUTH, "none")
    val userId = when (state) {
        is SessionState.NeedsRole -> state.userId
        is SessionState.NeedsOnboarding -> state.userId
        is SessionState.Ready -> state.userId
        else -> null
    }
    if (owner == null || owner.userId.isBlank() || owner.userId != userId) {
        return RootDestination(RootGate.PENDING, key)
    }
    val rawRole = when (state) {
        is SessionState.NeedsOnboarding -> state.role
        is SessionState.Ready -> state.role
        else -> null
    }
    val role = when (rawRole) {
        UserRole.HOSPITAL.storageKey -> UserRole.HOSPITAL
        UserRole.ENGINEER.storageKey -> UserRole.ENGINEER
        else -> null
    }
    return when {
        state is SessionState.NeedsRole || role == null -> RootDestination(RootGate.ROLE, key)
        state is SessionState.NeedsOnboarding -> RootDestination(RootGate.ONBOARDING, key, role)
        state is SessionState.Ready -> RootDestination(RootGate.MAIN, key, role)
        else -> RootDestination(RootGate.PENDING, key)
    }
}

/**
 * Root alone chooses the host. Every destination checks current admission before
 * composing its screen; a restored/exiting entry cannot flash a protected host.
 * Owner and role are part of the route so changing them destroys old entry VMs
 * and saved nested navigation. Same-login Unknown retains that entry invisibly.
 */
@Composable
internal fun RootSessionHost(
    presentation: SessionPresentation,
    onRefresh: (SessionOwner?) -> Unit,
    onSignOut: (SessionOwner?) -> Unit,
    slots: RootSessionSlots,
) {
    val navController = rememberNavController()
    val target = rootDestination(presentation)
    val initialRoute = remember { target.route }
    val latest by rememberUpdatedState(presentation)
    val latestSlots by rememberUpdatedState(slots)
    val refresh by rememberUpdatedState(onRefresh)
    val signOut by rememberUpdatedState(onSignOut)
    val focusManager = LocalFocusManager.current
    LaunchedEffect(presentation.resolvingAuth) {
        if (presentation.resolvingAuth) focusManager.clearFocus(force = true)
    }

    LaunchedEffect(target.route) {
        val entry = navController.currentBackStackEntry
        if (entry != null && !target.matches(entry)) {
            navController.navigate(target.route) {
                popUpTo(navController.graph.id) { inclusive = true }
                launchSingleTop = true
            }
        }
    }

    @Composable
    fun Content(entry: NavBackStackEntry) {
        val current = latest
        val admitted = rootDestination(current)
        if (!admitted.matches(entry)) return
        val capturedOwner = current.owner
        val capturedGate = admitted
        val guardedRefresh: () -> Unit = {
            val live = latest
            if (!live.resolvingAuth && live.owner == capturedOwner && rootDestination(live) == capturedGate) refresh(capturedOwner)
        }
        val guardedSignOut: () -> Unit = {
            val live = latest
            if (!live.resolvingAuth && capturedOwner != null && live.owner == capturedOwner &&
                rootDestination(live) == capturedGate) signOut(capturedOwner)
        }
        val contentModifier = if (current.resolvingAuth) {
            Modifier.fillMaxSize().alpha(0f).clearAndSetSemantics { }
                .focusProperties { canFocus = false }
        } else Modifier.fillMaxSize()
        Box(contentModifier) {
            when (admitted.gate) {
                RootGate.AUTH -> latestSlots.auth(guardedRefresh)
                RootGate.ROLE -> latestSlots.role(guardedRefresh, guardedSignOut)
                RootGate.ONBOARDING -> latestSlots.onboarding(
                    checkNotNull(admitted.role), current.baseProfileComplete, guardedRefresh,
                )
                RootGate.MAIN -> latestSlots.main(checkNotNull(admitted.role), guardedRefresh)
                RootGate.PENDING -> latestSlots.pending(guardedRefresh, guardedSignOut)
            }
        }
    }

    Box(Modifier.fillMaxSize()) {
        NavHost(
            navController = navController,
            startDestination = initialRoute,
            enterTransition = { EnterTransition.None },
            exitTransition = { ExitTransition.None },
            popEnterTransition = { EnterTransition.None },
            popExitTransition = { ExitTransition.None },
        ) {
            composable("root_auth") { Content(it) }
            listOf("root_role/{owner}", "root_pending/{owner}").forEach { route ->
                composable(route, arguments = listOf(navArgument("owner") { type = NavType.StringType })) { Content(it) }
            }
            listOf("root_main/{owner}/{role}", "root_onboarding/{owner}/{role}").forEach { route ->
                composable(route, arguments = listOf(
                    navArgument("owner") { type = NavType.StringType },
                    navArgument("role") { type = NavType.StringType },
                )) { Content(it) }
            }
        }
        if (presentation.resolvingAuth) {
            Box(Modifier.fillMaxSize().pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) awaitPointerEvent().changes.forEach { it.consume() }
                }
            }) { slots.resolving() }
        }
        BackHandler(enabled = presentation.resolvingAuth) { /* Keep the retained stack unchanged. */ }
    }
}
