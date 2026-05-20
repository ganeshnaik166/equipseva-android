package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Routes are referenced by string almost everywhere — the navigation graph,
 * push deep-link handler, and the back-stack restorer. Pin the route
 * formatters so a rename can't silently break a deep link or back-stack
 * entry under one of these helpers.
 */
class RoutesTest {

    @Test fun `repairJobDetailRoute appends the job id segment`() {
        assertEquals("repair/detail/job-1", Routes.repairJobDetailRoute("job-1"))
    }

    @Test fun `chatRoute appends the conversation id segment`() {
        assertEquals("chat/detail/conv-9", Routes.chatRoute("conv-9"))
    }

    @Test fun `engineerPublicProfileRoute appends the engineer id segment`() {
        assertEquals(
            "engineers/public/eng-1",
            Routes.engineerPublicProfileRoute("eng-1"),
        )
    }

    @Test fun `founderKycReviewRoute appends the user id segment`() {
        assertEquals(
            "${Routes.FOUNDER_KYC_REVIEW}/user-9",
            Routes.founderKycReviewRoute("user-9"),
        )
    }

    @Test fun `requestSentRoute with no params returns the bare route`() {
        // Use case: hospital submitted but the server hasn't returned an id
        // yet — the confirmation should still render.
        assertEquals(Routes.REQUEST_SENT, Routes.requestSentRoute(null, null))
        assertEquals(Routes.REQUEST_SENT, Routes.requestSentRoute("", ""))
    }

    @Test fun `requestSentRoute appends only the params that are non-blank`() {
        assertEquals(
            "${Routes.REQUEST_SENT}?jobId=job-1",
            Routes.requestSentRoute("job-1", null),
        )
        assertEquals(
            "${Routes.REQUEST_SENT}?jobNumber=RJ-001",
            Routes.requestSentRoute(null, "RJ-001"),
        )
        assertEquals(
            "${Routes.REQUEST_SENT}?jobId=job-1&jobNumber=RJ-001",
            Routes.requestSentRoute("job-1", "RJ-001"),
        )
    }

    @Test fun `addressFormRoute distinguishes new from edit`() {
        assertEquals(Routes.PROFILE_ADDRESS_FORM, Routes.addressFormRoute(null))
        assertEquals(
            "${Routes.PROFILE_ADDRESS_FORM}?addressId=addr-1",
            Routes.addressFormRoute("addr-1"),
        )
    }

    @Test fun `core route constants stay stable`() {
        // These strings appear in push deep links / NotificationDeepLink
        // tests — renaming any of them is a visible breakage.
        assertEquals("home", Routes.HOME)
        assertEquals("repair", Routes.REPAIR)
        assertEquals("profile", Routes.PROFILE)
        assertEquals("profile/kyc", Routes.KYC)
        assertEquals("notifications", Routes.NOTIFICATIONS)
    }
}
