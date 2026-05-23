package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the AMC creation wizard's step-navigation contract. Two
 * fixed-points worth defending:
 *
 *   * nextAmcWizardStep(Engineer) == Engineer — the last step is a
 *     fixed point so a "tap Next from last" doesn't wrap or crash.
 *   * previousAmcWizardStep(Scope) == Scope — the first step is a
 *     fixed point so a "tap Back from first" stays on Scope rather
 *     than returning null / wrapping.
 *
 * The strict-monotonic linear advance (Scope → FrequencyFee → Sla
 * → Engineer) is the wizard's load-bearing invariant. A regression
 * here would either skip a validation step or send the user back
 * to a step they've already filled.
 */
class AmcWizardStepNavTest {

    @Test fun `nextAmcWizardStep advances Scope to FrequencyFee`() {
        assertEquals(
            CreateAmcWizardViewModel.Step.FrequencyFee,
            nextAmcWizardStep(CreateAmcWizardViewModel.Step.Scope),
        )
    }

    @Test fun `nextAmcWizardStep advances FrequencyFee to Sla`() {
        assertEquals(
            CreateAmcWizardViewModel.Step.Sla,
            nextAmcWizardStep(CreateAmcWizardViewModel.Step.FrequencyFee),
        )
    }

    @Test fun `nextAmcWizardStep advances Sla to Engineer`() {
        assertEquals(
            CreateAmcWizardViewModel.Step.Engineer,
            nextAmcWizardStep(CreateAmcWizardViewModel.Step.Sla),
        )
    }

    @Test fun `nextAmcWizardStep is a fixed point at Engineer (last step)`() {
        // Pin so a "tap Next from last" doesn't wrap to Scope or
        // crash on a non-exhaustive when.
        assertEquals(
            CreateAmcWizardViewModel.Step.Engineer,
            nextAmcWizardStep(CreateAmcWizardViewModel.Step.Engineer),
        )
    }

    @Test fun `previousAmcWizardStep walks Engineer back to Sla`() {
        assertEquals(
            CreateAmcWizardViewModel.Step.Sla,
            previousAmcWizardStep(CreateAmcWizardViewModel.Step.Engineer),
        )
    }

    @Test fun `previousAmcWizardStep walks Sla back to FrequencyFee`() {
        assertEquals(
            CreateAmcWizardViewModel.Step.FrequencyFee,
            previousAmcWizardStep(CreateAmcWizardViewModel.Step.Sla),
        )
    }

    @Test fun `previousAmcWizardStep walks FrequencyFee back to Scope`() {
        assertEquals(
            CreateAmcWizardViewModel.Step.Scope,
            previousAmcWizardStep(CreateAmcWizardViewModel.Step.FrequencyFee),
        )
    }

    @Test fun `previousAmcWizardStep is a fixed point at Scope (first step)`() {
        // Pin so "tap Back from first" stays on Scope rather than
        // wrapping to Engineer or returning null.
        assertEquals(
            CreateAmcWizardViewModel.Step.Scope,
            previousAmcWizardStep(CreateAmcWizardViewModel.Step.Scope),
        )
    }

    @Test fun `forward then back returns to the original step (for non-fixed-points)`() {
        // Round-trip sanity: next(prev(s)) == s for every interior
        // step. Pin so the two helpers stay symmetric.
        listOf(
            CreateAmcWizardViewModel.Step.FrequencyFee,
            CreateAmcWizardViewModel.Step.Sla,
            CreateAmcWizardViewModel.Step.Engineer,
        ).forEach { s ->
            assertEquals(
                "expected next(prev($s)) == $s",
                s,
                nextAmcWizardStep(previousAmcWizardStep(s)),
            )
        }
    }
}
