package com.equipseva.app.core.observability

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.google.firebase.crashlytics.FirebaseCrashlytics
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Mirrors the current auth state into Crashlytics' user id slot, the
 * same way [SentryUserBridge] does for Sentry. Without this, every
 * Crashlytics non-fatal + native crash report carried an empty user id
 * — `CrashReporter.setUser()` existed in the codebase but had no
 * caller, so the field was never populated.
 *
 * Implications of the prior gap:
 *  - Crashlytics console "Affected users" was always zero.
 *  - Filtering crashes by user (founder forensics: "did engineer X hit
 *    this NPE?") was impossible.
 *  - Crashes from a stale session continued to attribute to nothing
 *    instead of being clearable on sign-out.
 *
 * Only the Supabase user id is attached — no email / phone. The id is
 * a server-generated UUID that carries no PII on its own.
 */
@Singleton
class CrashlyticsUserBridge @Inject constructor(
    private val authRepository: AuthRepository,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun attach() {
        scope.launch {
            authRepository.sessionState
                .distinctUntilChanged()
                .collect { session ->
                    when (session) {
                        is AuthSession.SignedIn ->
                            FirebaseCrashlytics.getInstance().setUserId(session.userId)
                        AuthSession.SignedOut,
                        AuthSession.Unknown ->
                            FirebaseCrashlytics.getInstance().setUserId("")
                    }
                }
        }
    }
}
