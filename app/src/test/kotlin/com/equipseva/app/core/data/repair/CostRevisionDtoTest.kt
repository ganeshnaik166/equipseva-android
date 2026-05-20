package com.equipseva.app.core.data.repair

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant

/**
 * The `propose_cost_revision` / `decide_cost_revision` SECURITY DEFINER RPCs
 * return a single JSONB row matching `public.repair_job_cost_revisions`.
 * These tests pin the wire shape so a SQL-side column rename (or
 * Postgrest's "snake_case in / camelCase out" being toggled) is caught
 * before it ships to a release build.
 */
class CostRevisionDtoTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test fun `decodes a proposed revision row from RPC JSON`() {
        val dto = json.decodeFromString(
            CostRevisionDto.serializer(),
            """
            {
              "id": "rev-1",
              "repair_job_id": "job-1",
              "engineer_user_id": "eng-1",
              "original_amount_rupees": 1500.0,
              "revised_amount_rupees": 2400.0,
              "reason": "needed a replacement sensor",
              "status": "proposed",
              "created_at": "2026-05-04T10:15:30Z",
              "decided_at": null,
              "decision_by": null
            }
            """.trimIndent(),
        )

        val domain = dto.toDomain()
        assertEquals("rev-1", domain.id)
        assertEquals("job-1", domain.repairJobId)
        assertEquals("eng-1", domain.engineerUserId)
        assertEquals(1500.0, domain.originalAmountRupees, 0.0)
        assertEquals(2400.0, domain.revisedAmountRupees, 0.0)
        assertEquals("needed a replacement sensor", domain.reason)
        assertEquals(CostRevisionStatus.Proposed, domain.status)
        assertEquals(Instant.parse("2026-05-04T10:15:30Z"), domain.createdAt)
        assertNull(domain.decidedAt)
        assertNull(domain.decisionBy)
    }

    @Test fun `decodes an approved revision and maps decision metadata`() {
        val dto = json.decodeFromString(
            CostRevisionDto.serializer(),
            """
            {
              "id": "rev-2",
              "repair_job_id": "job-2",
              "engineer_user_id": "eng-2",
              "original_amount_rupees": 800.0,
              "revised_amount_rupees": 950.0,
              "reason": "extra labour",
              "status": "approved",
              "created_at": "2026-05-04T10:00:00Z",
              "decided_at": "2026-05-04T11:00:00Z",
              "decision_by": "hosp-1"
            }
            """.trimIndent(),
        )

        val domain = dto.toDomain()
        assertEquals(CostRevisionStatus.Approved, domain.status)
        assertEquals(Instant.parse("2026-05-04T11:00:00Z"), domain.decidedAt)
        assertEquals("hosp-1", domain.decisionBy)
    }

    @Test fun `unknown status string falls back to Proposed`() {
        // Belt-and-braces — the SQL enum could grow a new variant before the
        // app catches up. fromKey() should not throw.
        assertEquals(CostRevisionStatus.Proposed, CostRevisionStatus.fromKey("partially_approved"))
        assertEquals(CostRevisionStatus.Proposed, CostRevisionStatus.fromKey(null))
        assertEquals(CostRevisionStatus.Proposed, CostRevisionStatus.fromKey(""))
    }

    @Test fun `fromKey is case-insensitive`() {
        assertEquals(CostRevisionStatus.Approved, CostRevisionStatus.fromKey("APPROVED"))
        assertEquals(CostRevisionStatus.Rejected, CostRevisionStatus.fromKey("Rejected"))
        assertEquals(CostRevisionStatus.Expired, CostRevisionStatus.fromKey("expired"))
    }

    @Test fun `unparseable timestamps degrade to null instead of throwing`() {
        // Server-side `to_jsonb(row)` should always emit ISO-8601, but if a
        // legacy row sneaks through with a malformed string we want the banner
        // to still render — just without a relative-time label.
        val dto = CostRevisionDto(
            id = "rev-3",
            repairJobId = "job-3",
            engineerUserId = "eng-3",
            originalAmountRupees = 100.0,
            revisedAmountRupees = 120.0,
            reason = "x",
            status = "proposed",
            createdAtIso = "not-a-timestamp",
            decidedAtIso = null,
        )
        val domain = dto.toDomain()
        assertNull(domain.createdAt)
    }

    @Test fun `every CostRevisionStatus has a stable wire key`() {
        // Pins the SQL enum contract — these strings are written as-is into
        // `repair_job_cost_revisions.status` and any rename would silently
        // break joins.
        assertEquals("proposed", CostRevisionStatus.Proposed.key)
        assertEquals("approved", CostRevisionStatus.Approved.key)
        assertEquals("rejected", CostRevisionStatus.Rejected.key)
        assertEquals("expired", CostRevisionStatus.Expired.key)
    }
}
