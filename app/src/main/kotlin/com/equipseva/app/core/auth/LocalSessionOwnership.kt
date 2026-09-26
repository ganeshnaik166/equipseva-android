package com.equipseva.app.core.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import java.util.Base64
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Independent local ownership for cleanup mutations. Only an agreeing observed
 * SignedIn and raw SDK identity can issue a ticket. Synchronous probes may
 * invalidate ownership, but never adopt a replacement login on their own.
 *
 * Tickets and parsed claims are isolation keys, not authorization. A boundary
 * missed by both the observer and every raw probe cannot be detected if its
 * final identity is identical. This monitor does not freeze SDK authentication;
 * each storage adapter must also serialize its guarded mutation with writers.
 */
@Singleton
class LocalSessionOwnership internal constructor(
    authRepository: AuthRepository,
    private val currentIdentity: () -> Identity?,
    scope: CoroutineScope,
) {
    @Inject constructor(authRepository: AuthRepository, supabase: SupabaseClient) : this(
        authRepository = authRepository,
        currentIdentity = {
            // Read one SDK snapshot; never assemble fields from separate reads.
            supabase.auth.currentSessionOrNull()?.let { session ->
                identityFromAccessToken(session.user?.id, session.accessToken)
            }
        },
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
    )

    data class Identity(val ownerId: String, val sessionId: String)
    class Ticket internal constructor(val identity: Identity, internal val generation: Long)

    private val fence = Any()
    private var generation = 0L
    private var issued: Ticket? = null
    private var explicitlyRetiredIdentity: Identity? = null

    init {
        // All fields are initialized before an immediately available auth
        // observation runs. Tests own this scope; production uses a singleton.
        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            authRepository.sessionState.collect { session ->
                synchronized(fence) {
                    when (session) {
                        AuthSession.SignedOut -> invalidateIssued()
                        AuthSession.Unknown -> checkedCurrent()
                        is AuthSession.SignedIn -> {
                            val identity = readIdentity()?.takeIf {
                                session.userId.isNotBlank() && it.ownerId == session.userId
                            }
                            if (identity == null || identity == explicitlyRetiredIdentity) {
                                invalidateIssued()
                            } else {
                                // Only an agreeing, distinct valid login can
                                // rearm an explicitly retired cached identity.
                                explicitlyRetiredIdentity = null
                                if (issued?.identity != identity) {
                                    invalidateIssued()
                                    issued = Ticket(identity, ++generation)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /** Capture before suspension; repeated captures share the exact ticket. */
    fun capture(): Ticket? = synchronized(fence) { checkedCurrent() }

    /**
     * Invoke only after entering the storage transform/transaction. [action]
     * must be a short non-suspending mutation; never acquire DataStore here.
     * Its exceptions propagate so the storage transaction can roll back.
     */
    fun withCurrent(ticket: Ticket?, action: () -> Unit): Boolean = synchronized(fence) {
        val current = checkedCurrent() ?: return@synchronized false
        if (ticket !== current || current.generation != generation) return@synchronized false
        action()
        true
    }

    /** Revoke only this issuer's current ticket; stale callers cannot retire B. */
    fun retire(ticket: Ticket): Boolean = synchronized(fence) {
        if (ticket !== issued || ticket.generation != generation) return@synchronized false
        explicitlyRetiredIdentity = ticket.identity
        invalidateIssued()
        true
    }

    // All methods below run under fence. Null covers absent and malformed raw
    // identity, so it cannot clear the explicit-retirement cache.
    private fun checkedCurrent(): Ticket? {
        val current = issued ?: return null
        if (readIdentity() != current.identity) {
            // Permanent invalidation prevents raw A -> B (observed here) -> A
            // from reviving this object, even before the auth observer runs.
            invalidateIssued()
            return null
        }
        return current
    }

    private fun invalidateIssued() {
        if (issued != null) {
            issued = null
            generation++
        }
    }

    private fun readIdentity(): Identity? = try {
        currentIdentity()?.takeIf { it.ownerId.isNotBlank() && it.sessionId.isNotBlank() }
    } catch (cancelled: CancellationException) {
        throw cancelled
    } catch (_: Exception) {
        null
    }

    companion object {
        /** Strict claim shape for local isolation, without a JWT authority claim. */
        internal fun identityFromAccessToken(ownerId: String?, accessToken: String): Identity? {
            if (ownerId.isNullOrBlank()) return null
            return try {
                val parts = accessToken.split('.')
                if (parts.size != 3 || parts.any { it.isBlank() }) return null
                val payload = String(Base64.getUrlDecoder().decode(parts[1]), Charsets.UTF_8)
                val claims = Json.parseToJsonElement(payload) as? JsonObject ?: return null
                val subject = claims["sub"] as? JsonPrimitive ?: return null
                if (!subject.isString || subject.content != ownerId) return null
                val session = claims["session_id"] as? JsonPrimitive ?: return null
                if (!session.isString || session.content.isBlank()) return null
                Identity(ownerId, session.content)
            } catch (_: IllegalArgumentException) {
                null
            }
        }
    }
}
