package com.equipseva.app.features.hospital

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1407 first-job-free promo helpers. */
class FirstJobFreeHelpersTest {

    @Test fun `headline by eligibility`() {
        assertEquals("Your first repair job is free", firstJobFreeHeadline(true))
        assertEquals("This offer isn't available", firstJobFreeHeadline(false))
    }

    @Test fun `known reason codes map to friendly text`() {
        assertEquals("You've already used this offer.", firstJobFreeReasonLabel("already_redeemed"))
        assertEquals(
            "This offer is for first-time hospitals only — you've already completed a job with us.",
            firstJobFreeReasonLabel("not_first_time_user"),
        )
        assertEquals(
            "Your account is under review, so this offer isn't available right now.",
            firstJobFreeReasonLabel("account_under_review"),
        )
    }

    @Test fun `null reason reads not-available (helper is only called when NOT eligible)`() {
        // r1468: null reason in the not-eligible branch means "no reason code",
        // not "eligible" — must not render the eligible-context string.
        assertEquals("This offer isn't available right now.", firstJobFreeReasonLabel(null))
    }

    @Test fun `unknown reason de-snakes`() {
        assertEquals("Some new reason", firstJobFreeReasonLabel("some_new_reason"))
    }
}
