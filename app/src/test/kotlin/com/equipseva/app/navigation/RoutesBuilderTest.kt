package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the Route builder helpers. These produce navigation route
 * strings consumed by `navController.navigate(...)`. A regression in
 * any builder (typo in the prefix, mis-encoded arg, drops a parameter)
 * would surface as a "destination not found" crash on tap, so pin the
 * exact wire shape every helper produces.
 */
class RoutesBuilderTest {

    private val sampleJobId = "11111111-2222-3333-4444-555555555555"
    private val sampleConvId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

    @Test fun `repairJobDetailRoute joins prefix and id`() {
        assertEquals("repair/detail/$sampleJobId", Routes.repairJobDetailRoute(sampleJobId))
    }

    @Test fun `chatRoute joins prefix and conversation id`() {
        assertEquals("chat/detail/$sampleConvId", Routes.chatRoute(sampleConvId))
    }

    @Test fun `engineerPublicProfileRoute joins prefix and engineer id`() {
        assertEquals(
            "engineers/public/eng-1",
            Routes.engineerPublicProfileRoute("eng-1"),
        )
    }

    @Test fun `founderKycReviewRoute joins prefix and user id`() {
        assertEquals(
            "founder/kyc/review/u-1",
            Routes.founderKycReviewRoute("u-1"),
        )
    }

    // ---- requestSentRoute query-args ----

    @Test fun `requestSentRoute with no args returns the bare prefix`() {
        assertEquals("hospital/request_sent", Routes.requestSentRoute(null, null))
    }

    @Test fun `requestSentRoute with blank args returns the bare prefix`() {
        // Blank args treated as absent (defensive — UI may pass empty
        // strings for missing data; route shouldn't expose `jobId=` etc.).
        assertEquals("hospital/request_sent", Routes.requestSentRoute("  ", ""))
    }

    @Test fun `requestSentRoute with jobId only appends single query param`() {
        assertEquals(
            "hospital/request_sent?jobId=j-1",
            Routes.requestSentRoute("j-1", null),
        )
    }

    @Test fun `requestSentRoute with jobNumber only appends single query param`() {
        assertEquals(
            "hospital/request_sent?jobNumber=RPR-007",
            Routes.requestSentRoute(null, "RPR-007"),
        )
    }

    @Test fun `requestSentRoute with both joins with ampersand`() {
        assertEquals(
            "hospital/request_sent?jobId=j-1&jobNumber=RPR-007",
            Routes.requestSentRoute("j-1", "RPR-007"),
        )
    }

    // ---- founderIntegrityRoute query encoding ----

    @Test fun `founderIntegrityRoute with no userId returns the bare prefix`() {
        assertEquals("founder/integrity", Routes.founderIntegrityRoute(null, null))
        assertEquals("founder/integrity", Routes.founderIntegrityRoute("  ", "ignored"))
    }

    @Test fun `founderIntegrityRoute with userId appends URL-encoded query`() {
        // user id is a uuid so encoding is a no-op; pin so a future
        // helper that drops URLEncoder is intentional.
        assertEquals(
            "founder/integrity?user=u-1",
            Routes.founderIntegrityRoute("u-1", null),
        )
    }

    @Test fun `founderIntegrityRoute encodes special chars in name param`() {
        // Display names can carry spaces, apostrophes, etc. Pin that the
        // URLEncoder runs over the name arg too.
        val route = Routes.founderIntegrityRoute("u-1", "O'Reilly Hospital & Clinic")
        assertEquals(
            // URLEncoder uses + for space and %-encodes ' and &.
            "founder/integrity?user=u-1&name=O%27Reilly+Hospital+%26+Clinic",
            route,
        )
    }

    @Test fun `founderIntegrityRoute with blank name omits the name param`() {
        // Defensive — a blank `name` shouldn't surface as `&name=`.
        assertEquals(
            "founder/integrity?user=u-1",
            Routes.founderIntegrityRoute("u-1", "  "),
        )
    }
}
