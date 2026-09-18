package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What the wizard tells a hospital after the first-month charge, and how a
 * prior contract's fee comes back into the fee field on renewal.
 */
class AmcWizardPaymentOutcomeTest {

    @Test fun `a verified charge says the contract is live`() {
        assertEquals("AMC contract activated.", amcWizardPaymentMessage(AmcWizardPaymentOutcome.Paid))
    }

    @Test fun `a charged-but-unconfirmed payment never asks for payment again`() {
        // Razorpay captured the money. The old copy ("complete it or it will
        // be cancelled in 24 hours") invited a SECOND charge for a contract
        // that was about to activate itself.
        val msg = amcWizardPaymentMessage(AmcWizardPaymentOutcome.ChargedAwaitingConfirmation)
        assertTrue("must confirm the money arrived: $msg", msg.startsWith("Payment received."))
        assertFalse("must not ask for payment again: $msg", msg.contains("Complete"))
        assertFalse("must not threaten cancellation: $msg", msg.contains("24 hours"))
    }

    @Test fun `an unpaid contract states the reaper deadline`() {
        assertEquals(
            "Contract pending payment. Complete it from the AMC detail screen or it " +
                "will be cancelled in 24 hours.",
            amcWizardPaymentMessage(AmcWizardPaymentOutcome.NotPaid(null)),
        )
    }

    @Test fun `razorpay's own reason leads the unpaid copy`() {
        // The reason is the only part the hospital can act on; it used to be
        // dropped in favour of the generic line.
        val msg = amcWizardPaymentMessage(
            AmcWizardPaymentOutcome.NotPaid("Your bank declined the payment."),
        )
        assertTrue(msg.startsWith("Your bank declined the payment. "))
        assertTrue(msg.endsWith("cancelled in 24 hours."))
    }

    @Test fun `a blank reason is ignored rather than padded`() {
        assertEquals(
            amcWizardPaymentMessage(AmcWizardPaymentOutcome.NotPaid(null)),
            amcWizardPaymentMessage(AmcWizardPaymentOutcome.NotPaid("   ")),
        )
    }

    // ---- amcFeeFieldValue ---------------------------------------------

    @Test fun `renewal prefill keeps paise`() {
        // Truncating to a whole number renewed a ₹2,999.50 contract at
        // ₹2,999 — a fee cut the hospital never asked for and never saw.
        assertEquals("2999.5", amcFeeFieldValue(2999.50))
        assertEquals("2999.99", amcFeeFieldValue(2999.99))
    }

    @Test fun `whole rupee fees carry no cosmetic decimals`() {
        assertEquals("5000", amcFeeFieldValue(5000.0))
        assertEquals("1000", amcFeeFieldValue(1000.00))
        assertEquals("0", amcFeeFieldValue(0.0))
    }

    @Test fun `the prefill is accepted by the fee gate it feeds`() {
        // The field's own validation parses with toDoubleOrNull(), which a
        // comma-decimal locale rendering ("2999,5") would fail.
        assertTrue(canProceedFrequencyFeeStep(amcFeeFieldValue(2999.50), 12))
        assertFalse(amcFeeFieldValue(2999.50).contains(","))
    }
}
