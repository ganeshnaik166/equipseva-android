package com.equipseva.app.core.data.reviews

/**
 * Buyer-submitted rating for a spare-part order. Persisted in `public.reviews`
 * with `review_type='spare_part_order'` + `related_entity_type='spare_part_order'`
 * + `related_entity_id = spare_part_orders.id`.
 *
 * `reviewerUserId` is always the authenticated buyer (RLS enforces
 * `auth.uid() = reviewer_user_id` on INSERT). `revieweeOrgId` is the supplier
 * organization — suppliers are org-owned, so there is no single `reviewee_user_id`
 * to attribute the rating to.
 */
data class OrderReview(
    val id: String,
    val orderId: String,
    val reviewerUserId: String,
    val revieweeOrgId: String?,
    val rating: Int,
    val comment: String?,
    val createdAtIso: String?,
)
