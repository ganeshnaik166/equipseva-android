package com.equipseva.app.core.data.founder

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Founder refund-authorization queue (round 488). Every RPC here is
 * is_founder()-gated server-side; a non-founder call errors. The founder can
 * review pending refund-authorization requests and approve (optional note) or
 * reject (reason >= 5 chars) each one.
 */
@Singleton
class FounderRefundRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class RefundRequest(
        @SerialName("id") val id: String,
        @SerialName("source_kind") val sourceKind: String = "",
        @SerialName("amount_rupees") val amountRupees: Double = 0.0,
        @SerialName("reason") val reason: String? = null,
        @SerialName("requester_email") val requesterEmail: String? = null,
        @SerialName("expires_at") val expiresAt: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
    )

    suspend fun pending(limit: Int = 50): Result<List<RefundRequest>> = runCatching {
        client.postgrest.rpc(
            function = "founder_pending_refund_authorizations",
            parameters = buildJsonObject { put("p_limit", JsonPrimitive(limit)) },
        ).decodeList<RefundRequest>()
    }

    suspend fun approve(requestId: String, note: String?): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "approve_refund_authorization",
            parameters = buildJsonObject {
                put("p_request_id", JsonPrimitive(requestId))
                put(
                    "p_approver_note",
                    note?.trim()?.takeIf { it.isNotEmpty() }?.let { JsonPrimitive(it) } ?: JsonNull,
                )
            },
        )
        Unit
    }

    suspend fun reject(requestId: String, reason: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "reject_refund_authorization",
            parameters = buildJsonObject {
                put("p_request_id", JsonPrimitive(requestId))
                put("p_reject_reason", JsonPrimitive(reason.trim()))
            },
        )
        Unit
    }
}
