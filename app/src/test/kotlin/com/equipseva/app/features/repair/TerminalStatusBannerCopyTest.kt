package com.equipseva.app.features.repair

import com.equipseva.app.core.data.repair.RepairJobStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the terminal-status banner copy / null-when-not-terminal
 * contract on RepairJobDetail.
 *
 * Critical regions:
 *   * Returns null for any non-terminal status — caller renders the
 *     5-step status stepper instead. A regression that surfaced a
 *     banner on "Requested" would replace the stepper visual on
 *     every open job.
 *   * Cancelled subtitle includes the admin's free-text reason
 *     (prefix "Reason: ") OR a canned "No further action needed."
 *     fallback. Pin the prefix so a refactor doesn't surface the
 *     bare admin sentence as if it were the engineer's copy.
 */
class TerminalStatusBannerCopyTest {

    // ---- Cancelled ----

    @Test fun `Cancelled with admin reason includes Reason prefix`() {
        val copy = terminalStatusBannerCopy(
            status = RepairJobStatus.Cancelled,
            cancellationReason = "Hospital double-booked another engineer.",
        )
        assertEquals("Job cancelled", copy!!.title)
        assertEquals("Reason: Hospital double-booked another engineer.", copy.subtitle)
    }

    @Test fun `Cancelled with null reason uses generic fallback`() {
        val copy = terminalStatusBannerCopy(
            status = RepairJobStatus.Cancelled,
            cancellationReason = null,
        )
        assertEquals("Job cancelled", copy!!.title)
        assertEquals("No further action needed.", copy.subtitle)
    }

    @Test fun `Cancelled with blank reason uses generic fallback`() {
        // Pin so an empty / whitespace-only reason from a half-typed
        // admin form doesn't surface as "Reason:  " awkwardness.
        val copy = terminalStatusBannerCopy(
            status = RepairJobStatus.Cancelled,
            cancellationReason = "   ",
        )
        assertEquals("No further action needed.", copy!!.subtitle)
    }

    // ---- Disputed ----

    @Test fun `Disputed shows canned admin-followup subtitle`() {
        val copy = terminalStatusBannerCopy(
            status = RepairJobStatus.Disputed,
            cancellationReason = null,
        )
        assertEquals("Job in dispute", copy!!.title)
        assertEquals("Add photos and context in the Escrow section below before admin decides. Both sides can respond.", copy.subtitle)
    }

    @Test fun `Disputed ignores cancellationReason (only used for Cancelled)`() {
        // Defensive — a stale row with both flags set must not
        // leak the cancellation reason onto the dispute banner.
        val copy = terminalStatusBannerCopy(
            status = RepairJobStatus.Disputed,
            cancellationReason = "Hospital booked too late",
        )
        assertEquals("Add photos and context in the Escrow section below before admin decides. Both sides can respond.", copy!!.subtitle)
        assertEquals(false, copy.subtitle.contains("Hospital"))
    }

    // ---- Non-terminal statuses return null ----

    @Test fun `Requested returns null (caller renders the stepper)`() {
        assertNull(terminalStatusBannerCopy(RepairJobStatus.Requested, null))
    }

    @Test fun `Assigned returns null`() {
        assertNull(terminalStatusBannerCopy(RepairJobStatus.Assigned, null))
    }

    @Test fun `EnRoute returns null`() {
        assertNull(terminalStatusBannerCopy(RepairJobStatus.EnRoute, null))
    }

    @Test fun `InProgress returns null`() {
        assertNull(terminalStatusBannerCopy(RepairJobStatus.InProgress, null))
    }

    @Test fun `Completed returns null (timeline reaches the end, no banner replacement)`() {
        // Completed is terminal but the stepper handles it (5/5
        // dots filled) — pin so a refactor doesn't accidentally
        // surface a banner on completed jobs.
        assertNull(terminalStatusBannerCopy(RepairJobStatus.Completed, null))
    }

    @Test fun `Unknown returns null`() {
        assertNull(terminalStatusBannerCopy(RepairJobStatus.Unknown, null))
    }
}
