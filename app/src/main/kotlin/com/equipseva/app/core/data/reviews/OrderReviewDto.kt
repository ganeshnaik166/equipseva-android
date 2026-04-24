package com.equipseva.app.core.data.reviews

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for reading a `public.reviews` row scoped to a spare-part order.
 * Only the columns the Android client consumes are mapped — the table has
 * photo / helpful_count / response fields we don't touch in v1.
 */
@Serializable
internal data class OrderReviewDto(
    val id: String,
    @SerialName("reviewer_user_id") val reviewerUserId: String,
    @SerialName("reviewee_org_id") val revieweeOrgId: String? = null,
    @SerialName("related_entity_id") val relatedEntityId: String,
    val rating: Int,
    val comment: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

internal fun OrderReviewDto.toDomain(): OrderReview = OrderReview(
    id = id,
    orderId = relatedEntityId,
    reviewerUserId = reviewerUserId,
    revieweeOrgId = revieweeOrgId,
    rating = rating,
    comment = comment,
    createdAtIso = createdAt,
)

/**
 * Insert payload. Fills the NOT NULL discriminator columns on `reviews`:
 *   - review_type = 'spare_part_order'
 *   - related_entity_type = 'spare_part_order'
 *   - related_entity_id = the order's UUID
 *
 * `reviewer_user_id` must match `auth.uid()` — RLS policy
 * "Users can write reviews" blocks anything else.
 */
@Serializable
internal data class OrderReviewInsertDto(
    @SerialName("reviewer_user_id") val reviewerUserId: String,
    @SerialName("reviewee_org_id") val revieweeOrgId: String?,
    @SerialName("review_type") val reviewType: String = ORDER_REVIEW_TYPE,
    @SerialName("related_entity_type") val relatedEntityType: String = ORDER_REVIEW_TYPE,
    @SerialName("related_entity_id") val relatedEntityId: String,
    val rating: Int,
    val comment: String?,
)

internal const val ORDER_REVIEW_TYPE = "spare_part_order"
