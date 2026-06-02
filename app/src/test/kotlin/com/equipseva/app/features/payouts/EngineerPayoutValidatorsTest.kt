package com.equipseva.app.features.payouts

import com.equipseva.app.features.payouts.EngineerPayoutMethodViewModel.Companion.accountNumberValid
import com.equipseva.app.features.payouts.EngineerPayoutMethodViewModel.Companion.ifscValid
import com.equipseva.app.features.payouts.EngineerPayoutMethodViewModel.Companion.vpaValid
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EngineerPayoutValidatorsTest {

    @Test
    fun `vpa accepts common UPI handles`() {
        listOf(
            "ganesh@oksbi",
            "ravi.kumar@okhdfcbank",
            "9876543210@paytm",
            "name-123@upi",
            "name_underscore@axisbank",
        ).forEach {
            assertTrue("should accept $it", vpaValid(it))
        }
    }

    @Test
    fun `vpa rejects malformed input`() {
        listOf(
            "noatsign",
            "two@@signs",
            "@nohandle",
            "handle@",
            "name@bank.com",     // dot in domain is not allowed by Razorpay shape
            "name@123bank",      // digits in domain reject
            "name with space@upi",
        ).forEach {
            assertFalse("should reject $it", vpaValid(it))
        }
    }

    @Test
    fun `ifsc is 11 chars, 4 letters + 0 + 6 alnum`() {
        assertTrue(ifscValid("SBIN0001234"))
        assertTrue(ifscValid("hdfc0a1b2c3"))   // lowercased input ok; viewmodel uppercases
        assertFalse(ifscValid("SBIN1001234"))  // 5th char must be 0
        assertFalse(ifscValid("SBIN000123"))   // too short
        assertFalse(ifscValid("S1IN0001234"))  // first 4 must be letters
    }

    @Test
    fun `account number length and digit-only`() {
        assertTrue(accountNumberValid("123456789"))
        assertTrue(accountNumberValid("123456789012345678"))
        assertFalse(accountNumberValid("12345678"))            // too short
        assertFalse(accountNumberValid("1234567890123456789")) // too long
        assertFalse(accountNumberValid("12345abc78"))           // letters
    }
}
