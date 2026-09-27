package com.equipseva.app.core.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionStatus
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.Base64
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/** A login-local navigation owner, never a substitute for server authorization. */
data class LoginTicketSnapshot(val userId: String, val sessionId: String)

/** Reads the SDK's current authenticated session synchronously at the decision boundary. */
@Singleton
class LoginTicketSource @Inject constructor(
    private val client: SupabaseClient,
    private val sessionManager: EncryptedSessionManager?,
) {
    /** Keeps existing direct-construction tests independent of Android storage. */
    constructor(client: SupabaseClient) : this(client, null)

    fun currentTicket(): LoginTicketSnapshot? {
        val session = client.auth.currentSessionOrNull() ?: return null
        return parseLoginTicket(session.user?.id, session.accessToken)
    }

    /** A stored identity may hold ingress only during SDK restoration; it never authorizes delivery. */
    fun provisionalStoredTicketDuringInitializing(): LoginTicketSnapshot? {
        if (client.auth.sessionStatus.value !is SessionStatus.Initializing) return null
        val ticket = sessionManager?.peekStoredLoginTicket() ?: return null
        return ticket.takeIf { client.auth.sessionStatus.value is SessionStatus.Initializing }
    }
}

/**
 * This decode only names the SDK session for local navigation. The decoded claims are not
 * authenticated here: RPCs and RLS must still validate their own caller and object access.
 */
internal fun parseLoginTicket(userId: String?, accessToken: String?): LoginTicketSnapshot? {
    val sdkUserId = canonicalUuid(userId) ?: return null
    if (accessToken.isNullOrBlank() || accessToken.length > MAX_ACCESS_TOKEN_LENGTH) return null

    val parts = accessToken.split('.', limit = 4)
    if (parts.size != 3 || parts.any(String::isBlank)) return null

    val header = decodeJwtObject(parts[0]) ?: return null
    val algorithm = header.stringClaim("alg") ?: return null
    if (algorithm.isBlank() || algorithm.equals("none", ignoreCase = true)) return null
    // This is only an envelope check; no client-side signature verification is claimed.
    val signature = try { Base64.getUrlDecoder().decode(parts[2]) } catch (_: IllegalArgumentException) { return null }
    if (signature.isEmpty()) return null
    val payload = decodeJwtObject(parts[1]) ?: return null

    val subject = canonicalUuid(payload.stringClaim("sub")) ?: return null
    val sessionId = canonicalUuid(payload.stringClaim("session_id")) ?: return null
    if (subject != sdkUserId) return null

    return LoginTicketSnapshot(userId = sdkUserId, sessionId = sessionId)
}

private fun decodeJwtObject(segment: String): JsonObject? = try {
    val bytes = Base64.getUrlDecoder().decode(segment)
    if (bytes.size > MAX_JWT_JSON_BYTES) null else {
        val text = Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes))
            .toString()
        Json.parseToJsonElement(text) as? JsonObject
    }
} catch (_: Exception) {
    null
}

private fun JsonObject.stringClaim(name: String): String? =
    (get(name) as? JsonPrimitive)?.takeIf { it.isString }?.content

private fun canonicalUuid(value: String?): String? =
    value?.takeIf { CANONICAL_UUID.matches(it) && !it.equals(NIL_UUID, ignoreCase = true) }
        ?.lowercase(Locale.ROOT)

private val CANONICAL_UUID = Regex(
    "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}",
)

private const val MAX_ACCESS_TOKEN_LENGTH = 64 * 1024
private const val MAX_JWT_JSON_BYTES = 32 * 1024
private const val NIL_UUID = "00000000-0000-0000-0000-000000000000"
