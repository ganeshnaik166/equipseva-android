package com.equipseva.app.features.amc

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the per-step `canProceed` gate on the AMC creation wizard.
 * Each step has its own minimum-data threshold; the gate prevents
 * the engineer from reaching the Razorpay "pay first month" tap with
 * invalid fee / SLA / engineer-id values.
 *
 * The Razorpay edge function will reject zero / negative / blank
 * fees as `amount_mismatch` — pin the client-side gate so the user
 * sees a disabled button rather than a confusing server-side toast.
 */
class CreateAmcWizardCanProceedTest {

    private fun state(
        step: CreateAmcWizardViewModel.Step,
        equipmentCategories: List<String> = listOf("imaging_radiology"),
        monthlyFeeRupees: String = "12000",
        visitsPerYear: Int = 12,
        responseTimeStandardHours: String = "24",
        responseTimeEmergencyHours: String = "4",
        primaryEngineerId: String = "eng-1",
    ) = CreateAmcWizardViewModel.UiState(
        step = step,
        equipmentCategories = equipmentCategories,
        monthlyFeeRupees = monthlyFeeRupees,
        visitsPerYear = visitsPerYear,
        responseTimeStandardHours = responseTimeStandardHours,
        responseTimeEmergencyHours = responseTimeEmergencyHours,
        primaryEngineerId = primaryEngineerId,
    )

    // ---- Scope step ----

    @Test fun `Scope step requires at least one equipment category`() {
        assertTrue(
            state(CreateAmcWizardViewModel.Step.Scope, equipmentCategories = listOf("imaging_radiology"))
                .canProceed,
        )
        assertFalse(
            state(CreateAmcWizardViewModel.Step.Scope, equipmentCategories = emptyList())
                .canProceed,
        )
    }

    @Test fun `Scope step ignores the other steps' fields`() {
        // A blank fee on Step 1 is irrelevant — it's only checked on
        // Step 2. Pin so the per-step partition stays.
        val s = state(
            CreateAmcWizardViewModel.Step.Scope,
            monthlyFeeRupees = "",
            responseTimeStandardHours = "",
        )
        assertTrue(s.canProceed)
    }

    // ---- FrequencyFee step ----

    @Test fun `FrequencyFee blank or unparseable fee blocks`() {
        assertFalse(
            state(CreateAmcWizardViewModel.Step.FrequencyFee, monthlyFeeRupees = "")
                .canProceed,
        )
        assertFalse(
            state(CreateAmcWizardViewModel.Step.FrequencyFee, monthlyFeeRupees = "abc")
                .canProceed,
        )
    }

    @Test fun `FrequencyFee zero or negative fee blocks`() {
        assertFalse(
            state(CreateAmcWizardViewModel.Step.FrequencyFee, monthlyFeeRupees = "0")
                .canProceed,
        )
        assertFalse(
            state(CreateAmcWizardViewModel.Step.FrequencyFee, monthlyFeeRupees = "-100")
                .canProceed,
        )
    }

    @Test fun `FrequencyFee zero visits per year blocks`() {
        assertFalse(
            state(CreateAmcWizardViewModel.Step.FrequencyFee, visitsPerYear = 0).canProceed,
        )
        assertFalse(
            state(CreateAmcWizardViewModel.Step.FrequencyFee, visitsPerYear = -1).canProceed,
        )
    }

    @Test fun `FrequencyFee positive fee + positive visits passes`() {
        assertTrue(
            state(
                CreateAmcWizardViewModel.Step.FrequencyFee,
                monthlyFeeRupees = "10000",
                visitsPerYear = 12,
            ).canProceed,
        )
    }

    @Test fun `FrequencyFee trims fee before parsing`() {
        assertTrue(
            state(CreateAmcWizardViewModel.Step.FrequencyFee, monthlyFeeRupees = "  10000  ")
                .canProceed,
        )
    }

    // ---- Sla step ----

    @Test fun `Sla blank standard or emergency blocks`() {
        assertFalse(
            state(CreateAmcWizardViewModel.Step.Sla, responseTimeStandardHours = "").canProceed,
        )
        assertFalse(
            state(CreateAmcWizardViewModel.Step.Sla, responseTimeEmergencyHours = "").canProceed,
        )
    }

    @Test fun `Sla zero or negative hours blocks`() {
        assertFalse(
            state(CreateAmcWizardViewModel.Step.Sla, responseTimeStandardHours = "0").canProceed,
        )
        assertFalse(
            state(CreateAmcWizardViewModel.Step.Sla, responseTimeEmergencyHours = "-1").canProceed,
        )
    }

    @Test fun `Sla fractional hours allowed (e_g_ 0_5h emergency response)`() {
        // Some hospitals offer 30-minute emergency SLAs — pin so the
        // > 0 check (not >= 1) stays.
        assertTrue(
            state(
                CreateAmcWizardViewModel.Step.Sla,
                responseTimeStandardHours = "8",
                responseTimeEmergencyHours = "0.5",
            ).canProceed,
        )
    }

    @Test fun `Sla unparseable hours blocks`() {
        assertFalse(
            state(CreateAmcWizardViewModel.Step.Sla, responseTimeStandardHours = "asap").canProceed,
        )
    }

    // ---- Engineer step ----

    @Test fun `Engineer step requires non-blank primaryEngineerId`() {
        assertTrue(
            state(CreateAmcWizardViewModel.Step.Engineer, primaryEngineerId = "eng-1").canProceed,
        )
        assertFalse(
            state(CreateAmcWizardViewModel.Step.Engineer, primaryEngineerId = "").canProceed,
        )
        assertFalse(
            state(CreateAmcWizardViewModel.Step.Engineer, primaryEngineerId = "   ").canProceed,
        )
    }
}
