package com.equipseva.app.features.amc

import android.app.Activity
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.data.analytics.AnalyticsClient
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.observability.CrashReporter
import com.equipseva.app.core.payments.PendingAmcContractsStore
import com.equipseva.app.core.payments.PendingAmcPaymentsStore
import com.equipseva.app.core.payments.RazorpayCheckoutLauncher
import com.equipseva.app.navigation.Routes
import io.mockk.Called
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

/**
 * Exercises the real submit boundary, not merely UiState.canProceed.
 * Contract writes are recorded and deliberately fail at the offline stub;
 * neither a server contract nor a payment is created by these tests.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CreateAmcWizardSlaSubmissionTest {
    private val dispatcher = StandardTestDispatcher()
    private val viewModels = mutableListOf<CreateAmcWizardViewModel>()
    private val activity = mockk<Activity>()

    @Before fun setUp() { Dispatchers.setMain(dispatcher) }

    @After fun tearDown() {
        viewModels.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private data class SlaWrite(val standard: Int, val emergency: Int)

    private inner class Fixture(
        standard: String = "8",
        emergency: String = "2",
    ) {
        val writes = mutableListOf<SlaWrite>()
        val messages = mutableListOf<String>()
        val navigated = mutableListOf<String>()
        val repo = mockk<AmcRepository>()
        val engineerRepo = mockk<EngineerDirectoryRepository>()
        val launcher = mockk<RazorpayCheckoutLauncher>()
        val payments = mockk<PendingAmcPaymentsStore>()
        val contracts = mockk<PendingAmcContractsStore>()
        val vm: CreateAmcWizardViewModel

        init {
            coEvery { engineerRepo.fetchPublicProfile("engineer-synthetic") } returns Result.success(null)
            coEvery {
                repo.createContract(
                    primaryEngineerId = any(),
                    visitFrequency = any(),
                    visitsPerYear = any(),
                    monthlyFeeRupees = any(),
                    startDate = any(),
                    endDate = any(),
                    equipmentCategories = any(),
                    scopeText = any(),
                    responseTimeEmergencyHours = any(),
                    responseTimeStandardHours = any(),
                    autoRenew = any(),
                    renewalTermMonths = any(),
                    fallbackEngineerIds = any(),
                )
            } coAnswers {
                writes += SlaWrite(standard = arg(9), emergency = arg(8))
                // Stop at the boundary being checked. No SDK fixture can
                // accidentally turn this into a real or mock payment flow.
                Result.failure(IOException("synthetic stop after captured contract arguments"))
            }
            vm = CreateAmcWizardViewModel(
                savedStateHandle = SavedStateHandle(
                    mapOf(
                        Routes.CREATE_AMC_ARG_ENGINEER_ID to "engineer-synthetic",
                        "amc.step" to CreateAmcWizardViewModel.Step.Engineer.name,
                        "amc.categories" to arrayOf("imaging_radiology"),
                        "amc.fee" to "5000",
                        "amc.stdHours" to standard,
                        "amc.emergHours" to emergency,
                    ),
                ),
                repo = repo,
                engineerRepo = engineerRepo,
                auth = mockk<AuthRepository>(),
                launcher = launcher,
                pendingPaymentsStore = payments,
                pendingContractsStore = contracts,
                analytics = mockk<AnalyticsClient>(relaxed = true),
                crashReporter = mockk<CrashReporter>(relaxed = true),
            )
            viewModels += vm
        }

        fun submit() {
            vm.submitAndPay(
                activity = activity,
                onSuccess = { navigated += it },
                onShowMessage = { messages += it },
            )
        }

        fun assertNoPaymentSideEffects() {
            verify { launcher wasNot Called }
            verify { payments wasNot Called }
            verify { contracts wasNot Called }
            assertTrue(navigated.isEmpty())
        }

        fun assertNoContractWrite() {
            assertTrue("Invalid restored SLA must not silently become defaults: $writes", writes.isEmpty())
            coVerify(exactly = 0) {
                repo.createContract(
                    any(), any(), any(), any(), any(), any(), any(), any(),
                    any(), any(), any(), any(), any(),
                )
            }
            assertFalse(vm.state.value.submitting)
            assertNotNull("Show an actionable validation error at the submit boundary", vm.state.value.error)
            assertNoPaymentSideEffects()
        }
    }

    @Test fun `padded whole hours that pass the page gate are submitted unchanged in value`() = runTest(dispatcher) {
        val f = Fixture()
        runCurrent()
        f.vm.setStep(CreateAmcWizardViewModel.Step.Sla)
        f.vm.setStandardHours(" 8 ")
        f.vm.setEmergencyHours(" 2 ")
        assertTrue("The user can pass this actual page gate", f.vm.state.value.canProceed)
        f.vm.next()
        assertEquals(CreateAmcWizardViewModel.Step.Engineer, f.vm.state.value.step)

        f.submit()
        runCurrent()

        assertEquals(listOf(SlaWrite(standard = 8, emergency = 2)), f.writes)
        assertFalse(f.vm.state.value.submitting)
        f.assertNoPaymentSideEffects()
    }

    @Test fun `ordinary valid whole hours still reach the contract write`() = runTest(dispatcher) {
        val f = Fixture(standard = "8", emergency = "2")
        runCurrent()

        f.submit()
        runCurrent()

        assertEquals(listOf(SlaWrite(standard = 8, emergency = 2)), f.writes)
        assertFalse(f.vm.state.value.submitting)
        f.assertNoPaymentSideEffects()
    }

    @Test fun `restored fractional emergency is rejected rather than becoming four`() = runTest(dispatcher) {
        val f = Fixture(emergency = "0.5")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored fractional standard is rejected rather than becoming twenty four`() = runTest(dispatcher) {
        val f = Fixture(standard = "8.5")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored blank emergency is rejected rather than defaulted`() = runTest(dispatcher) {
        val f = Fixture(emergency = "   ")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored blank standard is rejected rather than defaulted`() = runTest(dispatcher) {
        val f = Fixture(standard = "")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored zero emergency is rejected rather than coerced to one`() = runTest(dispatcher) {
        val f = Fixture(emergency = "0")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored zero standard is rejected rather than coerced to one`() = runTest(dispatcher) {
        val f = Fixture(standard = "0")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored negative emergency is rejected rather than coerced to one`() = runTest(dispatcher) {
        val f = Fixture(emergency = "-2")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored negative standard is rejected rather than coerced to one`() = runTest(dispatcher) {
        val f = Fixture(standard = "-8")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored overflowing emergency is rejected rather than defaulted`() = runTest(dispatcher) {
        val f = Fixture(emergency = "2147483648")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `restored overflowing standard is rejected rather than defaulted`() = runTest(dispatcher) {
        val f = Fixture(standard = "2147483648")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()
    }

    @Test fun `correcting a refused SLA permits a fresh valid contract attempt`() = runTest(dispatcher) {
        val f = Fixture(emergency = "0.5")
        runCurrent()
        f.submit()
        runCurrent()
        f.assertNoContractWrite()

        f.vm.setStandardHours(" 12 ")
        f.vm.setEmergencyHours(" 3 ")
        f.submit()
        runCurrent()

        assertEquals(listOf(SlaWrite(standard = 12, emergency = 3)), f.writes)
        assertFalse(f.vm.state.value.submitting)
        f.assertNoPaymentSideEffects()
    }
}
