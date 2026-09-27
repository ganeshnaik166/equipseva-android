package com.equipseva.app.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import com.equipseva.app.R
import com.equipseva.app.features.auth.SessionOwner
import com.equipseva.app.features.auth.SessionPresentation
import com.equipseva.app.features.auth.SessionState

internal data class RootBoundaryDecision(val hostKey: String, val mountHost: Boolean, val cover: Boolean)

/**
 * Reset every account-scoped NavHost when an authenticated owner changes or
 * signs out. A fresh SignedOut -> A signup retains its new auth form under an
 * opaque cover until A's profile validates, including the hospital phone
 * collection callback. Unknown retains the same login's back stack invisibly.
 */
internal class RootHostEpoch {
    private var previousOwner: SessionOwner? = null
    private var lastStableWasSignedOut = false
    private var authHandoffOwner: SessionOwner? = null
    private var authHandoffValidated = false
    private var lastValidatedRole: String? = null
    private var epoch = 0L

    fun decide(presentation: SessionPresentation, mountedOnce: Boolean): RootBoundaryDecision {
        val owner = presentation.owner
        if (previousOwner != owner) {
            if (previousOwner != null) {
                epoch++
                authHandoffOwner = null
                authHandoffValidated = false
            } else if (owner != null && lastStableWasSignedOut) {
                authHandoffOwner = owner
                authHandoffValidated = false
            }
            previousOwner = owner
            lastValidatedRole = null
        }
        if (presentation.state == SessionState.SignedOut) lastStableWasSignedOut = true
        else if (presentation.profileValidated) {
            lastStableWasSignedOut = false
            if (authHandoffOwner == owner) authHandoffValidated = true
            val role = presentation.validatedRole?.storageKey
            if (lastValidatedRole != null && lastValidatedRole != role) {
                // A role switch or server-side role removal must destroy the
                // previous role's saved routes before auth UI can render.
                epoch++
                authHandoffOwner = null
            }
            lastValidatedRole = role
        }

        val pending = presentation.state == SessionState.Loading &&
            owner != null && !presentation.profileValidated
        val preserveAuthHost = pending && authHandoffOwner == owner && !authHandoffValidated
        val mountHost = mountedOnce && (!pending || preserveAuthHost)
        // The owner-bearing key also prevents old NavController saveable state
        // from restoring for B after process death. An active signup keeps its
        // freshly mounted auth key until its phone collection has finished.
        val hostKey = if (owner != null && authHandoffOwner != owner) {
            "user:${owner.userId}:${owner.generation}:$epoch"
        } else "auth:$epoch"
        return RootBoundaryDecision(
            hostKey = hostKey,
            mountHost = mountHost,
            cover = !mountHost || pending || presentation.resolvingAuth,
        )
    }
}

/** This is the production composition/lifetime seam, exercised by JVM UI tests. */
@Composable
internal fun RootSessionBoundary(
    presentation: SessionPresentation,
    mountedOnce: Boolean,
    onRetry: () -> Unit = {},
    host: @Composable () -> Unit,
) {
    val epochs = remember { RootHostEpoch() }
    val decision = epochs.decide(presentation, mountedOnce)
    key(decision.hostKey) {
        Box(Modifier.fillMaxSize()) {
            if (decision.mountHost) {
                // NavHost entries use the nearest ViewModelStoreOwner. A
                // Compose key alone removes UI but can leave their stores
                // alive; clear the entire owner on account/role boundary.
                val scopedOwner = remember {
                    object : ViewModelStoreOwner {
                        override val viewModelStore = ViewModelStore()
                    }
                }
                DisposableEffect(scopedOwner) {
                    onDispose { scopedOwner.viewModelStore.clear() }
                }
                val hostModifier = if (decision.cover) {
                    Modifier.fillMaxSize().alpha(0f).clearAndSetSemantics { }
                        .focusProperties { canFocus = false }
                } else Modifier.fillMaxSize()
                Box(hostModifier) {
                    CompositionLocalProvider(LocalViewModelStoreOwner provides scopedOwner) {
                        host()
                    }
                }
            }
            if (decision.cover) {
                Box(
                    Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier.fillMaxSize().pointerInput(Unit) {
                            awaitPointerEventScope {
                                while (true) awaitPointerEvent().changes.forEach { it.consume() }
                            }
                        },
                    )
                    if (presentation.verificationFailed) {
                        Column(
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(24.dp),
                        ) {
                            Text(stringResource(R.string.auth_session_verify_error))
                            Button(onClick = onRetry) { Text(stringResource(R.string.common_retry)) }
                        }
                    } else CircularProgressIndicator()
                }
            }
        }
        BackHandler(enabled = decision.cover) { /* Retain the hidden host. */ }
    }
}
