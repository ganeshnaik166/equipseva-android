package com.equipseva.app.features.repair

import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.features.repair.RepairJobDetailViewModel.ViewerRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the two bottom-bar gates on the repair-job detail screen.
 *
 * Both exist because a CTA that cannot succeed is worse than no CTA:
 * the user spends effort on it (typing a mandatory cancellation reason,
 * composing a bid) and gets either silence or a server 42501.
 */
class RepairJobDetailBottomBarGatesTest {

    // ---- canCancelJob -------------------------------------------------

    @Test fun `hospital can cancel a requested or assigned job`() {
        assertTrue(canCancelJob(ViewerRole.Hospital, RepairJobStatus.Requested))
        assertTrue(canCancelJob(ViewerRole.Hospital, RepairJobStatus.Assigned))
    }

    @Test fun `hospital cannot cancel once work has started or the job has closed`() {
        for (status in listOf(
            RepairJobStatus.EnRoute,
            RepairJobStatus.InProgress,
            RepairJobStatus.Completed,
            RepairJobStatus.Cancelled,
            RepairJobStatus.Disputed,
        )) {
            assertFalse("hospital must not cancel from $status", canCancelJob(ViewerRole.Hospital, status))
        }
    }

    @Test fun `the assigned engineer gets no Cancel on an assigned job`() {
        // Critical pin. The engineer branch used to be true here, so the
        // assigned engineer saw "Cancel", opened the sheet, typed the
        // required 10-character reason, tapped "Cancel job" — and
        // nothing happened: cancelJob() routes through a hospital-only
        // transition and returns silently, and
        // repair_jobs_status_transition_guard raises "only the hospital
        // can cancel a job" besides. Restoring that branch needs a
        // server path first.
        assertFalse(canCancelJob(ViewerRole.Engineer, RepairJobStatus.Assigned))
    }

    @Test fun `no viewer other than the hospital can cancel from any status`() {
        for (status in RepairJobStatus.entries) {
            assertFalse(canCancelJob(ViewerRole.Engineer, status))
            assertFalse(canCancelJob(ViewerRole.Other, status))
        }
    }

    // ---- primaryCtaFor ------------------------------------------------

    private fun cta(
        viewerRole: ViewerRole,
        status: RepairJobStatus,
        isAssignedEngineer: Boolean = false,
        hasEngineerAssigned: Boolean = false,
        ownBidPending: Boolean = false,
        rated: Boolean = false,
    ) = primaryCtaFor(
        viewerRole = viewerRole,
        isAssignedEngineer = isAssignedEngineer,
        status = status,
        hasEngineerAssigned = hasEngineerAssigned,
        ownBidPending = ownBidPending,
        rated = rated,
    )

    @Test fun `engineer on an open requested job gets Place bid`() {
        val out = cta(ViewerRole.Engineer, RepairJobStatus.Requested)
        assertEquals(PrimaryCta.PlaceBid(editing = false), out)
    }

    @Test fun `an existing pending bid switches the same CTA to edit mode`() {
        val out = cta(ViewerRole.Engineer, RepairJobStatus.Requested, ownBidPending = true)
        assertEquals(PrimaryCta.PlaceBid(editing = true), out)
    }

    @Test fun `engineer gets NO bid composer on a pre-assigned requested job`() {
        // Critical pin — an AMC maintenance visit is Requested but
        // already has an engineer, and the hospital viewing it sees no
        // bids section at all (shouldShowBidsSection / the unmatched-job
        // banner already exclude it). A composer here invites a quote
        // into a void that nobody will ever read.
        assertNull(cta(ViewerRole.Engineer, RepairJobStatus.Requested, hasEngineerAssigned = true))
    }

    @Test fun `the assigned engineer gets Check in on an assigned job`() {
        assertEquals(
            PrimaryCta.CheckIn,
            cta(
                ViewerRole.Engineer,
                RepairJobStatus.Assigned,
                isAssignedEngineer = true,
                hasEngineerAssigned = true,
            ),
        )
    }

    @Test fun `an engineer who is not the assignee gets no on-site CTA`() {
        // The server 42501s them; a CTA that can only fail is a defect.
        for (status in listOf(
            RepairJobStatus.Assigned,
            RepairJobStatus.EnRoute,
            RepairJobStatus.InProgress,
        )) {
            assertNull(
                "non-assignee must get no CTA on $status",
                cta(ViewerRole.Engineer, status, isAssignedEngineer = false, hasEngineerAssigned = true),
            )
        }
    }

    @Test fun `the assigned engineer gets Mark done from en route and in progress`() {
        // complete_repair_job accepts assigned/en_route/in_progress, so
        // Mark done from EnRoute is valid and must stay offered.
        for (status in listOf(RepairJobStatus.EnRoute, RepairJobStatus.InProgress)) {
            assertEquals(
                PrimaryCta.MarkDone,
                cta(ViewerRole.Engineer, status, isAssignedEngineer = true, hasEngineerAssigned = true),
            )
        }
    }

    @Test fun `both sides get Rate on a completed job and RatedDone after rating`() {
        for (role in listOf(ViewerRole.Hospital, ViewerRole.Engineer)) {
            assertEquals(PrimaryCta.Rate, cta(role, RepairJobStatus.Completed, rated = false))
            assertEquals(PrimaryCta.RatedDone, cta(role, RepairJobStatus.Completed, rated = true))
        }
    }

    @Test fun `the Other role never gets a primary CTA`() {
        for (status in RepairJobStatus.entries) {
            assertNull(cta(ViewerRole.Other, status, hasEngineerAssigned = true))
        }
    }

    @Test fun `terminal statuses offer nothing to either side`() {
        for (status in listOf(RepairJobStatus.Cancelled, RepairJobStatus.Disputed)) {
            assertNull(cta(ViewerRole.Hospital, status))
            assertNull(cta(ViewerRole.Engineer, status, isAssignedEngineer = true))
        }
    }

    // ---- photoEvidenceRefusal -----------------------------------------

    @Test fun `no photos requested is not this helpers business`() {
        // Each caller has its own rule about whether zero photos is
        // allowed; the helper must not invent a photo requirement.
        assertNull(photoEvidenceRefusal(requested = 0, stashed = 0))
    }

    @Test fun `all photos stashed proceeds`() {
        assertNull(photoEvidenceRefusal(requested = 4, stashed = 4))
    }

    @Test fun `partial evidence still proceeds`() {
        // Stranding an engineer on-site over one oversized photo is the
        // worse outcome; the audit-trail report flags the shortfall.
        assertNull(photoEvidenceRefusal(requested = 4, stashed = 1))
    }

    @Test fun `zero of several stashed refuses with actionable copy`() {
        // Critical pin. The stash throws on empty bytes, on anything
        // over its size cap (reachable with a 50 MP camera JPEG) and on
        // a disk-write failure. Completing the job anyway is
        // unrecoverable: escrow auto-releases 48h after completion, so
        // the hospital is left with no after-photos to dispute against.
        val refusal = photoEvidenceRefusal(requested = 2, stashed = 0)
        assertNotNull(refusal)
        assertTrue("must suggest what to do, got: $refusal", refusal!!.contains("smaller"))
    }
}
