package com.equipseva.app.core.data.reviews

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The buyer-rating flow reads + writes `public.reviews` with hard-coded
 * discriminator columns (`review_type` + `related_entity_type` both
 * `spare_part_order`). These tests pin:
 *
 *  - the constant matches the RLS policy + the value the database expects, and
 *  - DTO ↔ domain mapping keeps `orderId` aligned with `related_entity_id`
 *    (the wire-side rename is easy to break with a typo).
 */
class OrderReviewDtoTest {

    private val json = Json { ignoreUnknownKeys = true }

    // Supabase-Kt's Postgrest serializer encodes defaults so the discriminator
    // columns (review_type / related_entity_type) actually land in the INSERT
    // body. Mirror that here so the test reflects what hits the wire, not
    // what a stock kotlinx.serialization Json (encodeDefaults=false) drops.
    private val postgrestLikeJson = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    @Test fun `domain mapping aliases related_entity_id to orderId`() {
        val dto = json.decodeFromString(
            OrderReviewDto.serializer(),
            """
            {
              "id": "rev-1",
              "reviewer_user_id": "buyer-1",
              "reviewee_org_id": "supplier-1",
              "related_entity_id": "order-42",
              "rating": 4,
              "comment": "shipped fast",
              "created_at": "2026-05-04T10:00:00Z"
            }
            """.trimIndent(),
        )

        val domain = dto.toDomain()
        assertEquals("rev-1", domain.id)
        assertEquals("order-42", domain.orderId)
        assertEquals("buyer-1", domain.reviewerUserId)
        assertEquals("supplier-1", domain.revieweeOrgId)
        assertEquals(4, domain.rating)
        assertEquals("shipped fast", domain.comment)
        assertEquals("2026-05-04T10:00:00Z", domain.createdAtIso)
    }

    @Test fun `nullable supplier org and comment round-trip`() {
        val dto = json.decodeFromString(
            OrderReviewDto.serializer(),
            """
            {
              "id": "rev-2",
              "reviewer_user_id": "buyer-2",
              "related_entity_id": "order-43",
              "rating": 5
            }
            """.trimIndent(),
        )

        val domain = dto.toDomain()
        assertNull(domain.revieweeOrgId)
        assertNull(domain.comment)
        assertNull(domain.createdAtIso)
        assertEquals(5, domain.rating)
    }

    @Test fun `insert payload uses the spare_part_order discriminator on both type columns`() {
        // If either of these renames silently, the INSERT fails the RLS
        // "Users can write reviews" check because the policy filters on
        // review_type. Pin the constant so a refactor that targets one
        // place can't drift the other.
        assertEquals("spare_part_order", ORDER_REVIEW_TYPE)

        val payload = OrderReviewInsertDto(
            reviewerUserId = "buyer-1",
            revieweeOrgId = "supplier-1",
            relatedEntityId = "order-42",
            rating = 4,
            comment = null,
        )
        assertEquals(ORDER_REVIEW_TYPE, payload.reviewType)
        assertEquals(ORDER_REVIEW_TYPE, payload.relatedEntityType)
    }

    @Test fun `insert payload serializes with snake_case keys for Postgrest`() {
        val payload = OrderReviewInsertDto(
            reviewerUserId = "buyer-1",
            revieweeOrgId = "supplier-1",
            relatedEntityId = "order-42",
            rating = 4,
            comment = "great",
        )
        val out = postgrestLikeJson.encodeToString(OrderReviewInsertDto.serializer(), payload)
        // The exact ordering isn't guaranteed by kotlinx.serialization, so
        // assert key presence instead of exact-string equality.
        listOf(
            "\"reviewer_user_id\":\"buyer-1\"",
            "\"reviewee_org_id\":\"supplier-1\"",
            "\"review_type\":\"spare_part_order\"",
            "\"related_entity_type\":\"spare_part_order\"",
            "\"related_entity_id\":\"order-42\"",
            "\"rating\":4",
            "\"comment\":\"great\"",
        ).forEach { fragment ->
            assertTrue("missing $fragment in $out", out.contains(fragment))
        }
    }
}
