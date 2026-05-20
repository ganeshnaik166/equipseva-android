package com.equipseva.app.core.observability

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.prefs.UserPrefs
import com.google.firebase.crashlytics.FirebaseCrashlytics
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.combine
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
    private val userPrefs: UserPrefs,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun attach() {
        scope.launch {
            // Round 463 — combine session + active-role pref. Multi-role
            // users flip activeRole at runtime; without observing the
            // pref the Crashlytics custom key would be set once at
            // sign-in and never updated.
            combine(
                authRepository.sessionState,
                userPrefs.activeRole,
            ) { session, role -> session to role }
                .distinctUntilChanged()
                .collect { (session, role) ->
                    val crashlytics = FirebaseCrashlytics.getInstance()
                    when (session) {
                        is AuthSession.SignedIn -> {
                            crashlytics.setUserId(session.userId)
                            crashlytics.setCustomKey(KEY_ACTIVE_ROLE, role.orEmpty())
                        }
                        AuthSession.SignedOut,
                        AuthSession.Unknown -> {
                            crashlytics.setUserId("")
                            crashlytics.setCustomKey(KEY_ACTIVE_ROLE, "")
                        }
                    }
                }
        }
    }

    private companion object {
        const val KEY_ACTIVE_ROLE = "active_role"
    }
}
