package com.equipseva.app.core.data.cart

import android.util.Log
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Drives the once-per-session reconcile of the server-side cart into local
 * Room. Called from [com.equipseva.app.EquipSevaApplication.onCreate] so the
 * pull happens on app start and on every subsequent sign-in (the auth flow
 * emits a fresh `SignedIn` event on each new session).
 *
 * Reconcile cadence: **session-start, not realtime.** Mutations made after
 * the initial pull flow through the CART_MUTATION outbox handler. We do not
 * subscribe to Postgres realtime here — that would double-fetch on every
 * server-side change and isn't needed for a cart that's only ever mutated
 * by the same user.
 *
 * De-dupe: `distinctUntilChanged` on the auth flow protects us from a
 * stuttering session emission re-fetching on every recomposition. Within a
 * single signed-in session we additionally guard with a `lastSyncedUserId`
 * so a hot-flow re-collection (e.g. ProcessLifecycle) doesn't spam the
 * server.
 */
@Singleton
class CartSyncBootstrap @Inject constructor(
    private val authRepository: AuthRepository,
    private val cartRepository: CartRepository,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Volatile
    private var lastSyncedUserId: String? = null

    fun start() {
        scope.launch {
            authRepository.sessionState
                .distinctUntilChanged()
                .collect { state ->
                    when (state) {
                        is AuthSession.SignedIn -> {
                            if (state.userId.isNotBlank() && state.userId != lastSyncedUserId) {
                                lastSyncedUserId = state.userId
                                cartRepository.pullFromServer(state.userId)
                                    .onFailure { Log.w(TAG, "Initial cart pull failed", it) }
                            }
                        }
                        is AuthSession.SignedOut -> {
                            // Reset the guard so the next sign-in pulls again.
                            lastSyncedUserId = null
                        }
                        AuthSession.Unknown -> Unit
                    }
                }
        }
    }

    private companion object {
        const val TAG = "CartSyncBootstrap"
    }
}
