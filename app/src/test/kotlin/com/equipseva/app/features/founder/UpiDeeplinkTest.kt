package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpiDeeplinkTest {

    /* --- looksLikeVpa --- */

    @Test
    fun `accepts common UPI handle shapes`() {
        listOf(
            "ganesh@oksbi",
            "ravi.kumar@okhdfcbank",
            "9876543210@paytm",
            "name-123@upi",
            "name_underscore@axisbank",
        ).forEach { assertTrue("$it should match", looksLikeVpa(it)) }
    }

    @Test
    fun `rejects bank account labels and free text`() {
        listOf(
            "SBI •••• 1234",
            "Bank •••• 9012",
            "no-at-sign",
            "two@@signs",
            "name@bank.com",  // dot in domain not accepted
        ).forEach { assertFalse("$it should NOT match", looksLikeVpa(it)) }
    }

    /* --- buildUpiDeeplink --- */

    @Test
    fun `builds NPCI-spec deeplink with all 5 params`() {
        val link = buildUpiDeeplink(
            vpa = "ganesh@oksbi",
            payeeName = "Ganesh Naik",
            amountRupees = 9.30,
            jobNumber = "RPR-00034",
        )
        assertEquals(
            "upi://pay?pa=ganesh%40oksbi&pn=Ganesh+Naik&am=9.30&cu=INR&tn=EquipSeva+RPR-00034",
            link,
        )
    }

    @Test
    fun `amount always 2 decimal places — never raw double truncation`() {
        val link = buildUpiDeeplink("x@y", "Z", 9.0, "RPR-X")
        // Naive Double.toString would emit "9.0", which some UPI apps
        // reject. Force "%.2f".
        assertTrue("amount missing 2dp: $link", link.contains("am=9.00"))
    }

    @Test
    fun `null or blank payee falls back to platform name`() {
        val link1 = buildUpiDeeplink("x@y", null, 9.30, "RPR-X")
        val link2 = buildUpiDeeplink("x@y", "", 9.30, "RPR-X")
        // URL-encoded "EquipSeva engineer" = "EquipSeva+engineer"
        assertTrue("link1 fallback: $link1", link1.contains("pn=EquipSeva+engineer"))
        assertTrue("link2 fallback: $link2", link2.contains("pn=EquipSeva+engineer"))
    }

    @Test
    fun `URL-encodes the vpa @ + spaces in name + special chars`() {
        val link = buildUpiDeeplink("a.b@c", "M&S Co", 100.0, "RPR/99")
        // @ → %40, & → %26, / → %2F, space → +
        assertTrue(link.contains("pa=a.b%40c"))
        assertTrue(link.contains("pn=M%26S+Co"))
        assertTrue(link.contains("tn=EquipSeva+RPR%2F99"))
    }
}
