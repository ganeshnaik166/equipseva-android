package com.equipseva.app.features.founder

import com.equipseva.app.core.util.Validators
import com.equipseva.app.features.payouts.EngineerPayoutMethodViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * WP24.T01 (ARCH-13): the founder payout screen and the engineer's payout form must agree on
 * what a UPI ID is. They used to carry separate regexes that differed on surrounding spaces.
 */
class VpaValidatorParityTest {
    private val samples = listOf(
        "name@okaxis",
        " name@okaxis ",
        "\tname@okaxis\n",
        "ravi.kumar@okhdfcbank",
        "9876543210@paytm",
        "name@bank.com",
        "name with space@upi",
        "two@@signs",
        "SBI •••• 1234",
        "",
        "   ",
    )

    @Test
    fun `founder and engineer screens accept exactly the same UPI IDs`() {
        samples.forEach { x ->
            val shared = Validators.vpaIsValid(x)
            assertEquals("looksLikeVpa(\"$x\")", shared, looksLikeVpa(x))
            assertEquals("vpaValid(\"$x\")", shared, EngineerPayoutMethodViewModel.vpaValid(x))
        }
    }

    @Test
    fun `the pay deeplink target is the trimmed UPI ID, and bank labels have none`() {
        assertEquals("name@okaxis", upiPayTarget(" name@okaxis "))
        assertEquals("ravi.kumar@okhdfcbank", upiPayTarget("ravi.kumar@okhdfcbank"))
        assertNull(upiPayTarget("SBI •••• 1234"))
        assertNull(upiPayTarget("   "))
    }
}
