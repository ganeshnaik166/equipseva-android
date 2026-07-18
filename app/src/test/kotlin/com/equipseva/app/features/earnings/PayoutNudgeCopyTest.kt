package com.equipseva.app.features.earnings

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the r1513 payout-nudge copy split: an engineer who already SAVED a
 * payout method (awaiting verification) must not be told to "set up" one,
 * and an engineer with none must not be told to "verify" a thing they
 * haven't added.
 */
class PayoutNudgeCopyTest {

    @Test fun `method exists reads awaiting-verification, never set-up`() {
        val (title, subtitle) = payoutNudgeCopy(methodExists = true)
        assertTrue(title.contains("awaiting verification"))
        assertFalse("must not tell them to set up: $subtitle", subtitle.contains("set up", ignoreCase = true))
        assertFalse(subtitle.contains("add your UPI", ignoreCase = true))
    }

    @Test fun `no method reads add-a-method, never verify`() {
        val (title, subtitle) = payoutNudgeCopy(methodExists = false)
        assertTrue(title.contains("add a payout method"))
        assertFalse("nothing to verify yet: $title", title.contains("verify", ignoreCase = true))
        assertTrue(subtitle.contains("add", ignoreCase = true))
    }
}
