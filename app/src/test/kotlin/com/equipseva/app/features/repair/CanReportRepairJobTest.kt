package com.equipseva.app.features.repair

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanReportRepairJobTest {

    @Test fun `engineer with loaded job can report`() {
        assertTrue(
            canReportRepairJob(
                jobIsLoaded = true,
                viewerRole = RepairJobDetailViewModel.ViewerRole.Engineer,
            ),
        )
    }

    @Test fun `hospital cannot report (self-report block)`() {
        // Critical regression target — pin the != gate. A flipped
        // == would let hospitals report their own jobs and pollute
        // the moderation queue with false positives.
        assertFalse(
            canReportRepairJob(
                jobIsLoaded = true,
                viewerRole = RepairJobDetailViewModel.ViewerRole.Hospital,
            ),
        )
    }

    @Test fun `Other role can report (founder browsing scenario)`() {
        // Pin — Other role still gets the CTA so founder-moderation
        // can submit reports manually.
        assertTrue(
            canReportRepairJob(
                jobIsLoaded = true,
                viewerRole = RepairJobDetailViewModel.ViewerRole.Other,
            ),
        )
    }

    @Test fun `job not loaded blocks report regardless of role`() {
        assertFalse(
            canReportRepairJob(
                jobIsLoaded = false,
                viewerRole = RepairJobDetailViewModel.ViewerRole.Engineer,
            ),
        )
        assertFalse(
            canReportRepairJob(
                jobIsLoaded = false,
                viewerRole = RepairJobDetailViewModel.ViewerRole.Other,
            ),
        )
    }

    @Test fun `hospital + job not loaded is still blocked`() {
        // Defensive — both gates fire.
        assertFalse(
            canReportRepairJob(
                jobIsLoaded = false,
                viewerRole = RepairJobDetailViewModel.ViewerRole.Hospital,
            ),
        )
    }
}
