package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentRowMetaLineTest {

    @Test fun `both razorpay id and relative time present`() {
        assertEquals(
            "rzp …ABCDEFGH · 4h ago",
            paymentRowMetaLine("order_ABCDEFGH", "4h"),
        )
    }

    @Test fun `razorpay id alone passes through with rzp prefix and ellipsis`() {
        assertEquals(
            "rzp …ABCDEFGH",
            paymentRowMetaLine("order_ABCDEFGH", null),
        )
    }

    @Test fun `relative time alone passes through with ago suffix`() {
        assertEquals(
            "4h ago",
            paymentRowMetaLine(null, "4h"),
        )
    }

    @Test fun `both null returns blank string`() {
        assertEquals("", paymentRowMetaLine(null, null))
    }

    @Test fun `ellipsis is U+2026 single codepoint not three dots`() {
        // Pin the Unicode glyph — diverging to "..." would inflate
        // the line width on a tight 12sp subline.
        val out = paymentRowMetaLine("order_X", null)
        assertTrue(out.contains('…'))
        assertEquals(false, out.contains("..."))
    }

    @Test fun `rzp prefix is lowercase`() {
        // Pin lowercase "rzp" — load-bearing source-system tag.
        val out = paymentRowMetaLine("X", null)
        assertTrue(out.startsWith("rzp "))
        assertEquals(false, out.startsWith("RZP "))
    }

    @Test fun `razorpay id is truncated to last 8 chars`() {
        // Pin takeLast(8) — Razorpay IDs share common "order_" prefix
        // and entropic suffix.
        val out = paymentRowMetaLine("order_1234567890ABCDEFGH", null)
        assertEquals("rzp …ABCDEFGH", out)
    }

    @Test fun `short razorpay id passes through intact under takeLast`() {
        // takeLast on shorter string returns the original.
        assertEquals(
            "rzp …abc",
            paymentRowMetaLine("abc", null),
        )
    }

    @Test fun `middle dot separator is U+00B7`() {
        val out = paymentRowMetaLine("X", "Y")
        assertTrue(out.contains(" · "))
    }
}
