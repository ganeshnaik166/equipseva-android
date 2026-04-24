package com.equipseva.app.core.data.reviews

interface OrderReviewRepository {
    /**
     * Find the buyer's own review for [orderId], or null if they haven't rated
     * this order yet. RLS on `reviews` is public-read, so this works for any
     * signed-in user — we filter by `reviewer_user_id = auth.uid()` at query
     * time to keep the response to at most one row.
     */
    suspend fun fetchMineForOrder(orderId: String): Result<OrderReview?>

    /**
     * Submit a new rating (1..5) with optional [comment] for [orderId].
     * [revieweeOrgId] should be the supplier org on the order. RLS enforces
     * that the caller is the reviewer; we do not additionally re-verify buyer
     * ownership client-side because RLS already scopes `reviews` writes to
     * `auth.uid() = reviewer_user_id` and the UI only offers this action on
     * orders the buyer can see (their own).
     */
    suspend fun submit(
        orderId: String,
        revieweeOrgId: String?,
        rating: Int,
        comment: String?,
    ): Result<OrderReview>
}
