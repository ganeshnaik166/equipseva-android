package com.equipseva.app.features.kyc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the KYC stepper's primary-CTA label. The critical region is
 * the last-step + rejected branch: a rejected engineer must see
 * "Re-submit for review" (signals the re-entry path), not "Submit
 * for review" (which lies — their row is already pending and gets
 * flipped, not created fresh).
 */
class StepperNextLabelTest {

    @Test fun `mid-stepper (not last) reads Next regardless of rejected flag`() {
        assertEquals("Next", stepperNextLabel(isLast = false, rejected = false))
        assertEquals("Next", stepperNextLabel(isLast = false, rejected = true))
    }

    @Test fun `last step initial submission reads Submit for review`() {
        assertEquals(
            "Submit for review",
            stepperNextLabel(isLast = true, rejected = false),
        )
    }

    @Test fun `last step + rejected reads Re-submit for review (signals re-entry)`() {
        // Pin the critical "Re-submit" wording — pin so a refactor
        // that collapsed the two last-step branches doesn't silently
        // mislead rejected engineers into thinking they're starting
        // fresh.
        assertEquals(
            "Re-submit for review",
            stepperNextLabel(isLast = true, rejected = true),
        )
    }

    @Test fun `rejected flag only matters on the last step (not mid-stepper)`() {
        // Defensive — surfacing "Re-submit" mid-stepper would
        // confuse a user before they'd touched the final form.
        val midStepNext = stepperNextLabel(isLast = false, rejected = true)
        assertEquals("Next", midStepNext)
    }

    @Test fun `last step labels read in title-case (not lowercase)`() {
        // Visual consistency — the bottom-bar CTA stays in title-
        // case across both initial + re-submit. Pin so a refactor
        // doesn't accidentally lowercase the verb.
        val initial = stepperNextLabel(isLast = true, rejected = false)
        val resubmit = stepperNextLabel(isLast = true, rejected = true)
        // First char of "Submit" / "Re-submit" must be uppercase.
        assertEquals(true, initial.first().isUpperCase())
        assertEquals(true, resubmit.first().isUpperCase())
    }
}
