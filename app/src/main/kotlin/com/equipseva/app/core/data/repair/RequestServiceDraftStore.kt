package com.equipseva.app.core.data.repair

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

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
 * Layout: a single JSON-serialized [RequestServiceFormDraft] string plus
 * a save-timestamp millis. Drafts older than 30 days are dropped on load
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
)

@Singleton
class RequestServiceDraftStore @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private object Keys {
        val DRAFT_JSON = stringPreferencesKey("draft_json")
        val DRAFT_TIMESTAMP_MS = longPreferencesKey("draft_timestamp_ms")
    }

    /**
     * Observe the current draft. Emits null if no draft exists or it has
     * expired (>30 days old). Stale/malformed drafts are cleared as a
     * side-effect so the next observer sees a clean slate.
     */
    fun observeDraft(): Flow<RequestServiceFormDraft?> =
        context.requestServiceDraftStore.data
            .map { prefs ->
                val json = prefs[Keys.DRAFT_JSON] ?: return@map null
                val timestamp = prefs[Keys.DRAFT_TIMESTAMP_MS] ?: return@map null
                val nowMs = System.currentTimeMillis()
                val ageMs = nowMs - timestamp
                if (ageMs > DRAFT_EXPIRY_MS) {
                    context.requestServiceDraftStore.edit {
                        it.remove(Keys.DRAFT_JSON)
                        it.remove(Keys.DRAFT_TIMESTAMP_MS)
                    }
                    null
                } else {
                    try {
                        Json.decodeFromString<RequestServiceFormDraft>(json)
                    } catch (e: Exception) {
                        // Malformed JSON — discard so we don't keep showing the
                        // recovery prompt for a draft we can't actually restore.
                        context.requestServiceDraftStore.edit {
                            it.remove(Keys.DRAFT_JSON)
                            it.remove(Keys.DRAFT_TIMESTAMP_MS)
                        }
                        null
                    }
                }
            }

    suspend fun loadDraft(): RequestServiceFormDraft? = observeDraft().first()

    /**
     * Persist the draft. Overwrites any existing draft. Timestamp is set
     * to now() so a subsequent [loadDraft] can compute age for expiry.
     */
    suspend fun saveDraft(draft: RequestServiceFormDraft) {
        val json = Json.encodeToString(RequestServiceFormDraft.serializer(), draft)
        context.requestServiceDraftStore.edit { prefs ->
            prefs[Keys.DRAFT_JSON] = json
            prefs[Keys.DRAFT_TIMESTAMP_MS] = System.currentTimeMillis()
        }
    }

    /**
     * Delete the draft. Called on successful submit and on "Discard" tap.
     */
    suspend fun clearDraft() {
        context.requestServiceDraftStore.edit { prefs ->
            prefs.remove(Keys.DRAFT_JSON)
            prefs.remove(Keys.DRAFT_TIMESTAMP_MS)
        }
    }

    private companion object {
        const val DRAFT_EXPIRY_DAYS = 30L
        const val DRAFT_EXPIRY_MS = DRAFT_EXPIRY_DAYS * 24L * 60L * 60L * 1000L
    }
}
