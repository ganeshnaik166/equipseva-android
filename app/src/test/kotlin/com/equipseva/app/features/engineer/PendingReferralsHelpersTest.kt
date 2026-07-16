package com.equipseva.app.features.engineer

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1406 pending-referral-confirmations helpers. */
class PendingReferralsHelpersTest {

    @Test fun `count label pluralises`() {
        assertEquals("1 referral", referralCountLabel(1))
        assertEquals("0 referrals", referralCountLabel(0))
        assertEquals("3 referrals", referralCountLabel(3))
    }

    @Test fun `headline embeds the count`() {
        assertEquals("1 referral awaiting your confirmation", pendingReferralsHeadline(1))
        assertEquals("4 referrals awaiting your confirmation", pendingReferralsHeadline(4))
    }

    @Test fun `confirm button label reflects in-flight state`() {
        assertEquals("Confirm", confirmButtonLabel(false))
        assertEquals("Confirming…", confirmButtonLabel(true))
    }
}
