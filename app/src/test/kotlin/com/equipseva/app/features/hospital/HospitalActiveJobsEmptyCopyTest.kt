package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HospitalActiveJobsEmptyCopyTest {

    @Test fun `All filter has Post-new-job CTA copy`() {
        // Critical pin — All is the ONLY branch with the "Post new
        // job below" CTA prompt.
        val (title, subtitle) = hospitalActiveJobsEmptyCopy(
            HospitalActiveJobsViewModel.Filter.All,
        )
        assertEquals("No repair jobs yet", title)
        assertTrue(subtitle.contains("Post new job below"))
    }

    @Test fun `Open filter explains the Open bucket without CTA`() {
        val (title, subtitle) = hospitalActiveJobsEmptyCopy(
            HospitalActiveJobsViewModel.Filter.Open,
        )
        assertEquals("No open jobs", title)
        assertEquals(
            "Jobs you post and haven't assigned yet appear here.",
            subtitle,
        )
    }

    @Test fun `Active filter explains the engineer-accepted bucket`() {
        val (title, subtitle) = hospitalActiveJobsEmptyCopy(
            HospitalActiveJobsViewModel.Filter.Active,
        )
        assertEquals("No jobs in progress", title)
        assertEquals(
            "Jobs an engineer has accepted appear here.",
            subtitle,
        )
    }

    @Test fun `Closed filter explains the finished-cancelled-disputed bucket`() {
        val (title, subtitle) = hospitalActiveJobsEmptyCopy(
            HospitalActiveJobsViewModel.Filter.Closed,
        )
        assertEquals("No closed jobs yet", title)
        assertEquals(
            "Finished, cancelled, or disputed jobs land here.",
            subtitle,
        )
    }

    @Test fun `Closed filter does NOT have Post-new-job CTA`() {
        // Critical pin — refactor that surfaced the CTA on Closed
        // would mislead the hospital into thinking posting another
        // job fixes the empty-closed state.
        val (_, subtitle) = hospitalActiveJobsEmptyCopy(
            HospitalActiveJobsViewModel.Filter.Closed,
        )
        assertEquals(false, subtitle.contains("Post new job"))
    }

    @Test fun `each filter has its own distinct title`() {
        val titles = setOf(
            hospitalActiveJobsEmptyCopy(HospitalActiveJobsViewModel.Filter.All).first,
            hospitalActiveJobsEmptyCopy(HospitalActiveJobsViewModel.Filter.Open).first,
            hospitalActiveJobsEmptyCopy(HospitalActiveJobsViewModel.Filter.Active).first,
            hospitalActiveJobsEmptyCopy(HospitalActiveJobsViewModel.Filter.Closed).first,
        )
        assertEquals(4, titles.size)
    }
}
