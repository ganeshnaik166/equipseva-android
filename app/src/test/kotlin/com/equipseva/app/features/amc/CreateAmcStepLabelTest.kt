package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the AMC creation wizard's step-header copy. The "Step N of 4"
 * is part of the product-spec acceptance criteria, and the unicode
 * middle-dot separator (`·`) is intentional — keep it from being
 * silently swapped to a hyphen or "•". Caught here so a refactor
 * (e.g. adding a fifth step) is intentional.
 */
class CreateAmcStepLabelTest {

    @Test fun `Scope is step 1 of 4`() {
        assertEquals(
            "Step 1 of 4 · Scope",
            stepLabel(CreateAmcWizardViewModel.Step.Scope),
        )
    }

    @Test fun `FrequencyFee is step 2 of 4`() {
        assertEquals(
            "Step 2 of 4 · Frequency + Fee",
            stepLabel(CreateAmcWizardViewModel.Step.FrequencyFee),
        )
    }

    @Test fun `Sla is step 3 of 4`() {
        assertEquals(
            "Step 3 of 4 · SLA",
            stepLabel(CreateAmcWizardViewModel.Step.Sla),
        )
    }

    @Test fun `Engineer is step 4 of 4`() {
        assertEquals(
            "Step 4 of 4 · Engineer",
            stepLabel(CreateAmcWizardViewModel.Step.Engineer),
        )
    }

    @Test fun `every step label is produced exactly once`() {
        // Sanity gate — if a future fifth step is added the wizard's
        // when() will fail-fast on compile (exhaustive). The set
        // assertion below guards against silent copy duplication.
        val labels = CreateAmcWizardViewModel.Step.entries.map(::stepLabel)
        assertEquals(labels.size, labels.toSet().size)
    }
}
