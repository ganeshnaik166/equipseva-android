package com.equipseva.app.core.observability

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.util.BuildConfigValues
import io.sentry.Sentry
import io.sentry.protocol.User
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Mirrors the current auth state into Sentry's user scope so crash + session
 * events carry a stable user_id (no email / phone — PII stays off).
 *
 * Cheap no-op when SENTRY_DSN is blank: Sentry.setUser on an uninitialized
 * SDK is a NoOpHub call, so we still attach the collector but nothing leaves
 * the device until a DSN is wired and SentryInitializer.init() succeeds.
 */
@Singleton
class SentryUserBridge @Inject constructor(
    private val authRepository: AuthRepository,
    private val userPrefs: UserPrefs,
) {
    // Long-lived; lifetime matches the Application process.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun attach() {
        // Skip wiring entirely when Sentry is a no-op anyway, so we don't
        // hold a collector for nothing.
        if (BuildConfigValues.sentryDsn.isBlank()) return
        scope.launch {
            // Round 463 — combine the auth session with the active-role
            // pref so the role tag follows runtime role flips, not just
            // sign-in. Multi-role users (hospital + engineer on the same
            // account) need crash forensics to know which side of the
            // marketplace they were on when the crash landed.
            combine(
                authRepository.sessionState,
                userPrefs.activeRole,
            ) { session, role -> session to role }
                .distinctUntilChanged()
                .collect { (session, role) ->
                    when (session) {
                        is AuthSession.SignedIn -> {
                            val user = User().apply { id = session.userId }
                            Sentry.setUser(user)
                            if (role.isNullOrBlank()) {
                                Sentry.removeTag(TAG_ACTIVE_ROLE)
                            } else {
                                Sentry.setTag(TAG_ACTIVE_ROLE, role)
                            }
                        }
                        AuthSession.SignedOut,
                        AuthSession.Unknown -> {
                            Sentry.setUser(null)
                            Sentry.removeTag(TAG_ACTIVE_ROLE)
                        }
                    }
                }
        }
    }

    private companion object {
        const val TAG_ACTIVE_ROLE = "active_role"
    }
}
