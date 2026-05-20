package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the Router.Event → DeepLinkHost.VerifiedEvent verification
 * seam. Today this is a verbatim forward — every router event is
 * trusted because NotificationDeepLink already filtered out
 * malformed kinds upstream. The test still exists because this is
 * the *one* place a future cross-user permission check (e.g.
 * "engineer is allowed to open this repair_job") would land. A
 * silent change here would either gate legitimate notifications
 * (silent drop = bad UX) or skip a check (security hole).
 */
class DeepLinkHostMappingTest {

    @Test fun `OpenRoute forwards route verbatim`() {
        val raw = DeepLinkRouter.Event.OpenRoute("jobDetail/abc-123")
        val verified = verifyRouterEvent(raw)
        assertEquals(
            DeepLinkHost.VerifiedEvent.OpenRoute("jobDetail/abc-123"),
            verified,
        )
    }

    @Test fun `OpenRoute preserves query parameters`() {
        val raw = DeepLinkRouter.Event.OpenRoute("engineer/profile?focus=kyc")
        val verified = verifyRouterEvent(raw)
        assertEquals(
            DeepLinkHost.VerifiedEvent.OpenRoute("engineer/profile?focus=kyc"),
            verified,
        )
    }

    @Test fun `OpenRoute preserves whitespace (no normalization)`() {
        // Verification is *not* the right layer to normalize / trim
        // — the router upstream already drops blanks, and the nav
        // graph downstream owns route validity. Pinning the
        // verbatim-forward contract so a future "be helpful" trim
        // doesn't mask an upstream bug.
        val raw = DeepLinkRouter.Event.OpenRoute("  jobs  ")
        val verified = verifyRouterEvent(raw)
        assertEquals(
            DeepLinkHost.VerifiedEvent.OpenRoute("  jobs  "),
            verified,
        )
    }

    @Test fun `OpenRoute with empty route still produces VerifiedEvent`() {
        // Defensive: the router upstream filters blank routes, so
        // this shouldn't happen — but the verifier doesn't double
        // check. Pinning the trust boundary so it's visible.
        val raw = DeepLinkRouter.Event.OpenRoute("")
        val verified = verifyRouterEvent(raw)
        assertEquals(
            DeepLinkHost.VerifiedEvent.OpenRoute(""),
            verified,
        )
    }
}
