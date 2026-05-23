package com.equipseva.app.features.engineer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the engineer Jobs hub's onboarding-hero copy per Status.
 *
 * Critical region: Pending state has ctaLabel = null. A regression
 * that always populated a CTA would surface a useless button to a
 * user whose only option is waiting for admin review. Pin the
 * null-ctaLabel branch so a refactor doesn't accidentally
 * resurrect it.
 *
 * Verified + Loading both return null — Verified means the user
 * sees the hub tiles instead, Loading means the caller renders a
 * spinner.
 */
class JobsHubOnboardingCopyTest {

    @Test fun `NotSignedIn shows sign-in copy with CTA`() {
        val copy = jobsHubOnboardingCopy(EngineerJobsHubViewModel.Status.NotSignedIn)!!
        assertEquals("Sign in to start taking jobs", copy.title)
        assertEquals("Sign in / Sign up", copy.ctaLabel)
        assertEquals(true, copy.body.contains("KYC"))
    }

    @Test fun `NotEngineer shows KYC-onboarding copy with Submit KYC CTA`() {
        val copy = jobsHubOnboardingCopy(EngineerJobsHubViewModel.Status.NotEngineer)!!
        assertEquals("Become a verified engineer", copy.title)
        assertEquals("Submit KYC", copy.ctaLabel)
    }

    @Test fun `Pending shows under-review copy with NULL CTA (cannot act)`() {
        // Critical pin — pending state means the user is blocked on
        // admin review. A CTA would be useless.
        val copy = jobsHubOnboardingCopy(EngineerJobsHubViewModel.Status.Pending)!!
        assertEquals("KYC under review", copy.title)
        assertNull(copy.ctaLabel)
        assertEquals(true, copy.body.contains("24h"))
    }

    @Test fun `Rejected shows resubmit copy with Open KYC CTA`() {
        val copy = jobsHubOnboardingCopy(EngineerJobsHubViewModel.Status.Rejected)!!
        // U+2014 em-dash in the title
        assertEquals(true, copy.title.contains('—'))
        assertEquals("Open KYC", copy.ctaLabel)
    }

    @Test fun `Verified returns null (hub renders tiles instead of hero)`() {
        assertNull(jobsHubOnboardingCopy(EngineerJobsHubViewModel.Status.Verified))
    }

    @Test fun `Loading returns null (caller renders spinner)`() {
        assertNull(jobsHubOnboardingCopy(EngineerJobsHubViewModel.Status.Loading))
    }

    @Test fun `all four onboarding states produce distinct titles`() {
        val titles = listOf(
            EngineerJobsHubViewModel.Status.NotSignedIn,
            EngineerJobsHubViewModel.Status.NotEngineer,
            EngineerJobsHubViewModel.Status.Pending,
            EngineerJobsHubViewModel.Status.Rejected,
        ).map { jobsHubOnboardingCopy(it)!!.title }
        assertEquals(titles.size, titles.toSet().size)
    }

    @Test fun `Pending body mentions the SLA hint (24h)`() {
        // The Pending body is the engineer's only signal about
        // when they'll hear back — pin the 24h reference so a
        // refactor doesn't drop the SLA promise.
        val copy = jobsHubOnboardingCopy(EngineerJobsHubViewModel.Status.Pending)!!
        assertEquals(true, copy.body.contains("24h"))
    }

    @Test fun `Rejected body mentions photo quality (most-common fix)`() {
        // Engineering insight — most KYC rejections are fixed by
        // re-uploading a clearer photo. Pin the body hint.
        val copy = jobsHubOnboardingCopy(EngineerJobsHubViewModel.Status.Rejected)!!
        assertEquals(true, copy.body.contains("photo"))
    }
}
