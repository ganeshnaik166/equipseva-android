package com.equipseva.app.core.data.cart

import android.util.Log
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.datetime.Clock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Drains a queued cart mutation against the server-side `cart_items` table so
 * the user's basket survives reinstall and roams across devices. Local Room
 * remains primary; this handler is the asynchronous server-persist arm.
 *
 * Wire kinds (see [RoomCartRepository.MutationKind]):
 *   - `add`, `increment`, `update_qty`, `setQuantity` → upsert
 *     (user_id, spare_part_id, quantity, updated_at=now). Idempotent: queueing
 *     "add" twice for the same part collapses to a single row at the latest
 *     quantity, never doubles up.
 *   - `remove` → delete one row by (user_id, spare_part_id).
 *   - `clear`  → delete every row for user_id.
 *
 * Owner gate (see MEMORY: `feedback_outbox_handler_owner_gate`): the payload
 * carries the original `userId`. On a shared device user B could otherwise
 * drain user A's queued mutations, and the server-side RLS would attribute
 * the write to whoever happens to be signed in. We compare against the
 * current `auth.uid`:
 *   - `Retry` when there is no session (signed out — try on next flush).
 *   - `GiveUp` on a real mismatch (different user signed in — drop quietly).
 *
 * Network / transient failures fall through as `Retry`; the worker's
 * MAX_ATTEMPTS cap drops poison entries after a fixed number of tries.
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

        return runCatching {
            when (payload.kind) {
                "add", "increment", "update_qty", "setQuantity" -> {
                    val partId = payload.sparePartId
                        ?: return@runCatching OutboxKindHandler.Outcome.GiveUp(
                            "Missing sparePartId on kind=${payload.kind}",
                        )
                    val qty = payload.quantity
                        ?: return@runCatching OutboxKindHandler.Outcome.GiveUp(
                            "Missing quantity on kind=${payload.kind}",
                        )
                    // Server check constraint is 1..99. Clamp defensively so a
                    // stale enqueue doesn't poison-loop on RLS / 23514.
                    val safeQty = qty.coerceIn(MIN_QTY, MAX_QTY)
                    supabase.from(TABLE).upsert(
                        CartItemRow(
                            user_id = payload.userId,
                            spare_part_id = partId,
                            quantity = safeQty,
                            updated_at = Clock.System.now().toString(),
                        ),
                    ) {
                        onConflict = "user_id,spare_part_id"
                    }
                    OutboxKindHandler.Outcome.Success
                }
                "remove" -> {
                    val partId = payload.sparePartId
                        ?: return@runCatching OutboxKindHandler.Outcome.GiveUp(
                            "Missing sparePartId on kind=remove",
                        )
                    supabase.from(TABLE).delete {
                        filter {
                            eq("user_id", payload.userId)
                            eq("spare_part_id", partId)
                        }
                    }
                    OutboxKindHandler.Outcome.Success
                }
                "clear" -> {
                    supabase.from(TABLE).delete {
                        filter { eq("user_id", payload.userId) }
                    }
                    OutboxKindHandler.Outcome.Success
                }
                else -> OutboxKindHandler.Outcome.GiveUp("Unknown cart kind: ${payload.kind}")
            }
        }.getOrElse { err ->
            Log.w(TAG, "Cart drain failed (kind=${payload.kind} part=${payload.sparePartId})", err)
            OutboxKindHandler.Outcome.Retry(err)
        }
    }

    @Serializable
    private data class CartItemRow(
        val user_id: String,
        val spare_part_id: String,
        val quantity: Int,
        val updated_at: String,
    )

    companion object {
        private const val TAG = "CartOutboxHandler"
        private const val TABLE = "cart_items"
        private const val MIN_QTY = 1
        private const val MAX_QTY = 99
    }
}

@Serializable
data class CartMutationPayload(
    /** One of "add", "increment", "update_qty", "setQuantity", "remove", "clear". */
    val kind: String,
    val userId: String,
    val sparePartId: String? = null,
    val quantity: Int? = null,
)
