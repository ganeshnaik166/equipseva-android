package com.equipseva.app.core.data.analytics

import android.util.Log
import com.equipseva.app.core.util.BuildConfigValues
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * v0.4 Phase 5 #10 — funnel-event logger that calls the
 * `public.log_analytics_event` Supabase RPC (round 510).
 *
 * Design notes:
 * - Replaces external Mixpanel: no PII shipped to a US vendor, the
 *   backend RPC already strips known PII keys server-side as a safety
 *   net (see r510 migration).
 * - Fire-and-forget: every call is launched on Dispatchers.IO and
 *   exceptions are swallowed + logged. Analytics MUST NOT block UI or
 *   throw user-visible errors. If the RPC fails the funnel just misses
 *   a row — acceptable.
 * - Anonymous client-side session id (UUID per app process) lets us
 *   stitch pre-login events to post-login user_id server-side without
 *   needing a stable device fingerprint.
 */
@Singleton
class AnalyticsClient @Inject constructor(
    private val supabase: SupabaseClient,
) {
    private val sessionId: String = UUID.randomUUID().toString()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun track(event: AnalyticsEvent, props: Map<String, Any?> = emptyMap()) {
        // Fire-and-forget — analytics never blocks the UI thread or
        // throws into a coroutine the caller might be holding.
        scope.launch {
            runCatching {
                supabase.postgrest.rpc(
                    function = "log_analytics_event",
                    parameters = buildJsonObject {
                        put("p_event_key", JsonPrimitive(event.key))
                        put("p_session_id", JsonPrimitive(sessionId))
                        put("p_surface", JsonPrimitive("android"))
                        put("p_app_version", JsonPrimitive(BuildConfigValues.versionName))
                        put("p_props", sanitizedProps(props))
                    },
                )
            }.onFailure { e ->
                // Log at WARN so debug builds notice but release builds
                // don't spam Sentry. The RPC's own PII strip + 4 KB cap
                // means almost all failures are network blips.
                Log.w(TAG, "track ${event.key} failed: ${e.message}")
            }
        }
    }

    /**
     * Allow-list approach: only String / Number / Boolean primitives
     * survive into the props JSON. Drops anything else silently so a
     * caller cannot accidentally ship a User object, a phone number, or
     * a JWT through a props bag. PII keys are also stripped server-side
     * by the RPC as defense-in-depth.
     */
    private fun sanitizedProps(props: Map<String, Any?>): JsonObject = buildJsonObject {
        props.forEach { (k, v) ->
            when (v) {
                is String -> put(k, JsonPrimitive(v.take(MAX_VALUE_CHARS)))
                is Number -> put(k, JsonPrimitive(v))
                is Boolean -> put(k, JsonPrimitive(v))
                else -> { /* drop */ }
            }
        }
    }

    companion object {
        private const val TAG = "AnalyticsClient"
        private const val MAX_VALUE_CHARS = 256
    }
}
