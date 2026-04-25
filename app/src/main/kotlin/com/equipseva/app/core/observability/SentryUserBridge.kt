package com.equipseva.app.core.observability

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.util.BuildConfigValues
import io.sentry.Sentry
import io.sentry.protocol.User
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
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
) {
    // Long-lived; lifetime matches the Application process.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun attach() {
        // Skip wiring entirely when Sentry is a no-op anyway, so we don't
        // hold a collector for nothing.
        if (BuildConfigValues.sentryDsn.isBlank()) return
        scope.launch {
            authRepository.sessionState
                .distinctUntilChanged()
                .collect { session ->
                    when (session) {
                        is AuthSession.SignedIn -> {
                            val user = User().apply { id = session.userId }
                            Sentry.setUser(user)
                        }
                        AuthSession.SignedOut,
                        AuthSession.Unknown -> Sentry.setUser(null)
                    }
                }
        }
    }
}
