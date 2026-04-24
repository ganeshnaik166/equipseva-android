package com.equipseva.app.core.data.reviews

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseOrderReviewRepository @Inject constructor(
    private val client: SupabaseClient,
) : OrderReviewRepository {

    override suspend fun fetchMineForOrder(orderId: String): Result<OrderReview?> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) {
            "No authenticated user"
        }
        client.from(TABLE).select {
            filter {
                eq("related_entity_type", ORDER_REVIEW_TYPE)
                eq("related_entity_id", orderId)
                eq("reviewer_user_id", userId)
            }
            limit(count = 1)
        }.decodeList<OrderReviewDto>().firstOrNull()?.toDomain()
    }

    override suspend fun submit(
        orderId: String,
        revieweeOrgId: String?,
        rating: Int,
        comment: String?,
    ): Result<OrderReview> = runCatching {
        require(rating in 1..5) { "Rating must be 1..5" }
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) {
            "No authenticated user"
        }
        val payload = OrderReviewInsertDto(
            reviewerUserId = userId,
            revieweeOrgId = revieweeOrgId?.takeIf { it.isNotBlank() },
            relatedEntityId = orderId,
            rating = rating,
            comment = comment?.trim()?.take(MAX_COMMENT_LEN)?.takeIf { it.isNotBlank() },
        )
        client.from(TABLE).insert(payload) {
            select()
        }.decodeSingle<OrderReviewDto>().toDomain()
    }

    private companion object {
        const val TABLE = "reviews"
        // UI cap; server has no length check today, but we keep payloads small.
        const val MAX_COMMENT_LEN = 500
    }
}
