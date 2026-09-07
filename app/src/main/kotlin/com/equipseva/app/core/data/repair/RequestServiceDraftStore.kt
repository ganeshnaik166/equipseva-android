package com.equipseva.app.core.data.repair

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import java.util.Base64
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.contentOrNull

private val Context.requestServiceDraftStore by preferencesDataStore("request_service_draft")

/**
 * v0.3.5 round 471 — persistent draft storage for the RequestService form's
 * auto-save + recovery flow. The booking form has 6+ sections on a long
 * scroll (equipment → issue → photos → severity → when → where → budget);
 * hospital users routinely task-switch mid-fill to copy a serial number
 * or look up a model, the OS kills the process, and the entire form is
 * gone. SavedStateHandle covers config-change + short-lived process death
 * within ViewModel scope but not "killed yesterday, opens app today",
 * which is where this DataStore steps in.
 *
 * Layout: a JSON draft, timestamp, owner and authenticated session ID.
 * Ownerless legacy drafts are discarded, never adopted by the next user.
 * Drafts older than 30 days are dropped on load
 * so a stale form from last month doesn't surprise the user with values
 * they no longer want.
 *
 * Photo URIs intentionally only carry uploaded Supabase storage paths
 * (e.g. `<userId>/issue-…jpg`) — local file:// URIs would expire when
 * the process dies and the temp files are reaped.
 *
 * Cleared on successful submit; cleared on user "Discard" tap.
 */
@Serializable
data class RequestServiceFormDraft(
    val category: String, // RepairEquipmentCategory.storageKey
    val urgency: String,  // RepairJobUrgency.storageKey
    val brand: String,
    val model: String,
    val serial: String,
    val siteAddress: String,
    val siteLocation: String,
    val pickedDateMillis: Long?,
    val siteLatitude: Double?,
    val siteLongitude: Double?,
    val issue: String,
    val budget: String,
    val photoUris: List<String>, // Uploaded Supabase paths (e.g. userId/issue-xxx.jpg)
    val selectedSlot: Int = -1,
)

@Singleton
class RequestServiceDraftStore internal constructor(
    private val dataStore: DataStore<Preferences>,
    authRepository: AuthRepository,
    private val currentIdentity: () -> Identity?,
    scope: CoroutineScope,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) {
    @Inject constructor(
        @ApplicationContext context: Context,
        authRepository: AuthRepository,
        supabase: SupabaseClient,
    ) : this(
        dataStore = context.requestServiceDraftStore,
        authRepository = authRepository,
        currentIdentity = {
            supabase.auth.currentSessionOrNull()?.let { session ->
                session.user?.id?.takeIf { it.isNotBlank() }?.let { ownerId ->
                    identityFromAccessToken(ownerId, session.accessToken) ?: Identity(ownerId, null)
                }
            }
        },
        // Singleton lifetime; tests provide their own cancellable scope.
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
    )

    /** A session identifier is a local isolation key, never an authorization claim. */
    data class Identity(val ownerId: String, val sessionId: String?)

    /** Captured before asynchronous work. Fresh login invalidates even the same owner's lease. */
    class Lease internal constructor(val identity: Identity, internal val generation: Long)

    private val fence = Any()
    private var generation = 0L
    private var writeEpoch = UUID.randomUUID().toString()
    private var clearedIdentity: Identity? = null
    private var blockedIdentity: Identity? = null
    private val _activeSession = MutableStateFlow<Lease?>(null)
    val activeSession: StateFlow<Lease?> = _activeSession.asStateFlow()

    init {
        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            authRepository.sessionState.collect { auth ->
                // SDK initialization during resume must not erase a valid form.
                if (auth is AuthSession.Unknown) return@collect
                val identity = (auth as? AuthSession.SignedIn)?.let { signedIn ->
                    currentIdentity()?.takeIf { it.ownerId == signedIn.userId }
                }
                synchronized(fence) {
                    // Unsupported token shapes have no stable session ID. Only
                    // an observed empty SDK session proves their old login ended;
                    // a SignedOut wrapper around a still-cached login does not.
                    if (auth is AuthSession.SignedOut && currentIdentity() == null &&
                        blockedIdentity?.sessionId == null
                    ) blockedIdentity = null
                    // A transient SignedOut event must not allow the SDK to reuse
                    // the exact login that explicit local cleanup already fenced.
                    if (identity != null && identity != blockedIdentity) blockedIdentity = null
                    val allowed = identity?.takeUnless { it == blockedIdentity }
                    if (_activeSession.value?.identity != allowed) {
                        generation++
                        _activeSession.value = allowed?.let { Lease(it, generation) }
                    }
                }
            }
        }
    }

    private object Keys {
        val DRAFT_JSON = stringPreferencesKey("draft_json")
        val DRAFT_TIMESTAMP_MS = longPreferencesKey("draft_timestamp_ms")
        val OWNER_ID = stringPreferencesKey("draft_owner_id")
        val SESSION_ID = stringPreferencesKey("draft_session_id")
        val WRITE_EPOCH = stringPreferencesKey("draft_write_epoch")
    }

    fun isCurrent(lease: Lease): Boolean = synchronized(fence) {
        _activeSession.value == lease && currentIdentity() == lease.identity
    }

    /** Capture alongside the form snapshot, before debounce or other suspension. */
    fun writeEpoch(lease: Lease): String? = synchronized(fence) {
        writeEpoch.takeIf { isCurrent(lease) }
    }

    /** Stale readers cannot expose another session or delete a newer writer's draft. */
    fun observeDraft(lease: Lease): Flow<RequestServiceFormDraft?> =
        dataStore.data
            .map { prefs ->
                if (!isCurrent(lease)) return@map null
                val json = prefs[Keys.DRAFT_JSON]
                val timestamp = prefs[Keys.DRAFT_TIMESTAMP_MS]
                val validOwner = prefs.belongsTo(lease.identity)
                val notCleared = synchronized(fence) {
                    clearedIdentity != lease.identity || prefs[Keys.WRITE_EPOCH] == writeEpoch
                }
                val draft = if (validOwner && notCleared && json != null && timestamp != null &&
                    nowMillis() - timestamp <= DRAFT_EXPIRY_MS
                ) {
                    runCatching { Json.decodeFromString<RequestServiceFormDraft>(json) }.getOrNull()
                } else null
                if (draft == null && json != null) {
                    dataStore.edit { latest ->
                        synchronized(fence) {
                            // Compare the entire observed envelope, not just its owner.
                            if (isCurrent(lease) && latest[Keys.DRAFT_JSON] == json &&
                                latest[Keys.DRAFT_TIMESTAMP_MS] == timestamp &&
                                latest[Keys.OWNER_ID] == prefs[Keys.OWNER_ID] &&
                                latest[Keys.SESSION_ID] == prefs[Keys.SESSION_ID] &&
                                latest[Keys.WRITE_EPOCH] == prefs[Keys.WRITE_EPOCH]
                            ) latest.removeDraft()
                        }
                    }
                }
                draft.takeIf { isCurrent(lease) }
            }

    suspend fun loadDraft(lease: Lease): RequestServiceFormDraft? = observeDraft(lease).first()

    /**
     * Persist the draft. Overwrites any existing draft. Timestamp is set
     * to now() so a subsequent [loadDraft] can compute age for expiry.
     */
    suspend fun saveDraft(
        lease: Lease,
        draft: RequestServiceFormDraft,
        expectedWriteEpoch: String? = writeEpoch(lease),
    ) {
        // Unknown token shape disables persistence, not the booking form itself.
        val sessionId = lease.identity.sessionId ?: return
        if (!isCurrent(lease)) return
        val json = Json.encodeToString(RequestServiceFormDraft.serializer(), draft)
        dataStore.edit { prefs ->
            synchronized(fence) {
                if (isCurrent(lease) && expectedWriteEpoch == writeEpoch) {
                    prefs[Keys.DRAFT_JSON] = json
                    prefs[Keys.DRAFT_TIMESTAMP_MS] = nowMillis()
                    prefs[Keys.OWNER_ID] = lease.identity.ownerId
                    prefs[Keys.SESSION_ID] = sessionId
                    prefs[Keys.WRITE_EPOCH] = writeEpoch
                }
            }
        }
    }

    /**
     * Delete the draft. Called on successful submit and on "Discard" tap.
     */
    suspend fun clearDraft(lease: Lease) {
        val nextEpoch = synchronized(fence) {
            if (!isCurrent(lease)) return
            clearedIdentity = lease.identity
            UUID.randomUUID().toString().also { writeEpoch = it }
        }
        dataStore.edit { prefs ->
            synchronized(fence) {
                if (isCurrent(lease) && writeEpoch == nextEpoch && prefs.belongsTo(lease.identity) &&
                    prefs[Keys.WRITE_EPOCH] != nextEpoch
                ) prefs.removeDraft()
            }
        }
    }

    /**
     * Fence synchronously, before the first disk/network suspension. A failed disk
     * clear still leaves every old callback invalid. A new session's draft cannot
     * be erased by a delayed cleanup from the departing session.
     */
    suspend fun fenceAndClearForSignOut() {
        val departing = synchronized(fence) {
            val identity = _activeSession.value?.identity ?: currentIdentity()
            blockedIdentity = identity
            generation++
            _activeSession.value = null
            identity
        }
        dataStore.edit { prefs ->
            if (prefs[Keys.OWNER_ID] == null ||
                (departing != null && prefs.belongsTo(departing))
            ) prefs.removeDraft()
        }
    }

    private fun Preferences.belongsTo(identity: Identity): Boolean =
        identity.sessionId != null && this[Keys.OWNER_ID] == identity.ownerId &&
            this[Keys.SESSION_ID] == identity.sessionId

    private fun androidx.datastore.preferences.core.MutablePreferences.removeDraft() {
        remove(Keys.DRAFT_JSON)
        remove(Keys.DRAFT_TIMESTAMP_MS)
        remove(Keys.OWNER_ID)
        remove(Keys.SESSION_ID)
        remove(Keys.WRITE_EPOCH)
    }

    companion object {
        const val DRAFT_EXPIRY_DAYS = 30L
        private const val DRAFT_EXPIRY_MS = DRAFT_EXPIRY_DAYS * 24L * 60L * 60L * 1000L

        internal fun identityFromAccessToken(ownerId: String?, accessToken: String): Identity? {
            if (ownerId.isNullOrBlank()) return null
            return runCatching {
                val payload = accessToken.split('.').takeIf { it.size == 3 }?.get(1)
                    ?: return null
                val claims = Json.parseToJsonElement(
                    String(Base64.getUrlDecoder().decode(payload), Charsets.UTF_8),
                ).jsonObject
                if (claims["sub"]?.jsonPrimitive?.contentOrNull != ownerId) return null
                val sessionId = claims["session_id"]?.jsonPrimitive?.contentOrNull
                    ?.takeIf { it.isNotBlank() } ?: return null
                Identity(ownerId, sessionId)
            }.getOrNull()
        }
    }
}
