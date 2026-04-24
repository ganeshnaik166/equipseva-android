package com.equipseva.app.core.data.cart

import android.util.Log
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Drains queued cart mutations. Cart is a local-first Room table in Phase 1 and
 * there is no server-side `cart_items` endpoint yet (see `mcp__supabase__list_tables`
 * — only `spare_parts` and `spare_part_orders` exist, no per-user cart). So this
 * handler is intentionally a no-op that drops the outbox row cleanly once the
 * owner gate passes. The plumbing sits here so that when a server-side cart
 * table lands, the upsert/delete branches can be filled in without re-wiring
 * every call site.
 *
 * Owner gate (see MEMORY: `feedback_outbox_handler_owner_gate`): the payload
 * carries the original `userId`. On a shared device user B could otherwise
 * drain user A's queued mutations. We compare against the current `auth.uid`:
 *   - `Retry` when there is no session (signed out — try again on next flush).
 *   - `GiveUp` on a real mismatch (different user signed in — just drop).
 *
 * Idempotency: drop-on-success is trivially idempotent, and a real future
 * server implementation should also be safe to replay (upsert on conflict /
 * delete-if-exists) because outbox drain is at-least-once.
 */
class CartMutationOutboxHandler @Inject constructor(
    private val supabase: SupabaseClient,
    private val json: Json,
) : OutboxKindHandler {

    override suspend fun handle(entry: OutboxEntryEntity): OutboxKindHandler.Outcome {
        val payload = runCatching { json.decodeFromString<CartMutationPayload>(entry.payload) }
            .getOrElse { return OutboxKindHandler.Outcome.GiveUp("Malformed payload: ${it.message}") }

        val currentUid = supabase.auth.currentUserOrNull()?.id
            ?: return OutboxKindHandler.Outcome.Retry(
                IllegalStateException("No auth session — deferring cart drain"),
            )
        if (currentUid != payload.userId) {
            return OutboxKindHandler.Outcome.GiveUp(
                "Cart owner mismatch: queued as ${payload.userId}, current auth is $currentUid",
            )
        }

        // No server `cart_items` table yet — treat as drained no-op.
        Log.i(
            TAG,
            "cart mutation queued but no server endpoint; dropped kind=${payload.kind} partId=${payload.sparePartId}",
        )
        return OutboxKindHandler.Outcome.Success
    }

    companion object {
        private const val TAG = "CartOutboxHandler"
    }
}

@Serializable
data class CartMutationPayload(
    /** One of "add", "update_qty", "remove", "clear". */
    val kind: String,
    val userId: String,
    val sparePartId: String? = null,
    val quantity: Int? = null,
)
