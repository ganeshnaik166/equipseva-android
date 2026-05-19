package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

class RoutesTest {

    // requestSentRoute — builds the post-submit confirmation URL with
    // optional jobId / jobNumber query args. The empty/null cases matter
    // because the confirmation copy + "View job" CTA gate on what's
    // present; passing a bad URL silently drops the CTA.

    @Test fun `requestSentRoute returns bare path when both args null`() {
        assertEquals(Routes.REQUEST_SENT, Routes.requestSentRoute(null, null))
    }

    @Test fun `requestSentRoute returns bare path when both args blank`() {
        // Blank arg is treated like null — same UX intent ("no job to point at").
        assertEquals(Routes.REQUEST_SENT, Routes.requestSentRoute("", "  "))
    }

    @Test fun `requestSentRoute includes jobId only`() {
        assertEquals(
            "${Routes.REQUEST_SENT}?jobId=abc-123",
            Routes.requestSentRoute("abc-123", null),
        )
    }

    @Test fun `requestSentRoute includes jobNumber only`() {
        assertEquals(
            "${Routes.REQUEST_SENT}?jobNumber=RPR-00027",
            Routes.requestSentRoute(null, "RPR-00027"),
        )
    }

    @Test fun `requestSentRoute joins both with ampersand`() {
        assertEquals(
            "${Routes.REQUEST_SENT}?jobId=abc-123&jobNumber=RPR-00027",
            Routes.requestSentRoute("abc-123", "RPR-00027"),
        )
    }

    // Static one-arg route builders — guard against accidental refactor
    // that breaks deep-link integrity (notification taps, App Links).

    @Test fun `repairJobDetailRoute appends jobId`() {
        assertEquals("${Routes.REPAIR_DETAIL}/abc-123", Routes.repairJobDetailRoute("abc-123"))
    }

    @Test fun `chatRoute appends conversationId`() {
        assertEquals("${Routes.CHAT_DETAIL}/conv-9", Routes.chatRoute("conv-9"))
    }

    @Test fun `engineerPublicProfileRoute appends engineerId`() {
        assertEquals(
            "${Routes.ENGINEER_PUBLIC_PROFILE}/eng-42",
            Routes.engineerPublicProfileRoute("eng-42"),
        )
    }

    @Test fun `founderKycReviewRoute appends userId`() {
        assertEquals(
            "${Routes.FOUNDER_KYC_REVIEW}/user-7",
            Routes.founderKycReviewRoute("user-7"),
        )
    }

    // Round 360/369 — founderIntegrityRoute. URL-encoding matters because
    // buyer names contain spaces, ampersands, unicode (Hindi names),
    // slashes (S/O initials). A naive concat would corrupt the nav arg
    // and the destination screen would parse the wrong filter.

    @Test fun `founderIntegrityRoute null userId returns bare path`() {
        assertEquals(Routes.FOUNDER_INTEGRITY, Routes.founderIntegrityRoute(null, null))
        assertEquals(Routes.FOUNDER_INTEGRITY, Routes.founderIntegrityRoute(null, "ignored"))
    }

    @Test fun `founderIntegrityRoute blank userId returns bare path`() {
        assertEquals(Routes.FOUNDER_INTEGRITY, Routes.founderIntegrityRoute("", "ignored"))
        assertEquals(Routes.FOUNDER_INTEGRITY, Routes.founderIntegrityRoute("  ", null))
    }

    @Test fun `founderIntegrityRoute encodes userId only`() {
        assertEquals(
            "${Routes.FOUNDER_INTEGRITY}?user=abc-123",
            Routes.founderIntegrityRoute("abc-123", null),
        )
    }

    @Test fun `founderIntegrityRoute encodes both userId and name`() {
        assertEquals(
            "${Routes.FOUNDER_INTEGRITY}?user=abc-123&name=Asha",
            Routes.founderIntegrityRoute("abc-123", "Asha"),
        )
    }

    @Test fun `founderIntegrityRoute url-encodes spaces in name`() {
        assertEquals(
            "${Routes.FOUNDER_INTEGRITY}?user=u1&name=Asha+Devi",
            Routes.founderIntegrityRoute("u1", "Asha Devi"),
        )
    }

    @Test fun `founderIntegrityRoute url-encodes ampersand in name`() {
        // "&" must not survive raw — it would terminate the user= param
        // and the destination would parse a phantom second arg.
        assertEquals(
            "${Routes.FOUNDER_INTEGRITY}?user=u1&name=A+%26+Co",
            Routes.founderIntegrityRoute("u1", "A & Co"),
        )
    }

    @Test fun `founderIntegrityRoute url-encodes slash in name`() {
        assertEquals(
            "${Routes.FOUNDER_INTEGRITY}?user=u1&name=Asha+S%2FO+Ramu",
            Routes.founderIntegrityRoute("u1", "Asha S/O Ramu"),
        )
    }

    @Test fun `founderIntegrityRoute skips name when blank`() {
        assertEquals(
            "${Routes.FOUNDER_INTEGRITY}?user=u1",
            Routes.founderIntegrityRoute("u1", ""),
        )
        assertEquals(
            "${Routes.FOUNDER_INTEGRITY}?user=u1",
            Routes.founderIntegrityRoute("u1", "  "),
        )
    }
}
