package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the founder Payments queue chip's (text, PillKind) mapping.
 * Accepts the diverging status vocab emitted by Razorpay's edge-fn
 * + the server-side webhook receivers.
 *
 * Critical regions:
 *   * Both "cancelled" (UK) and "canceled" (US) map to Danger —
 *     Razorpay's API and our internal triggers use different
 *     spellings; pin so a refactor that picks one doesn't silently
 *     leave the other rendering as Neutral.
 *   * Null / unknown statuses fold to "UNKNOWN" with Neutral so a
 *     stale row that lost its column doesn't render an empty chip.
 *   * Text is uppercased — visual emphasis on a status the founder
 *     is triaging.
 */
class PaymentStatusChipTextAndKindTest {

    // ---- Success bucket ----

    @Test fun `completed maps to Success`() {
        val (text, kind) = paymentStatusChipTextAndKind("completed")
        assertEquals("COMPLETED", text)
        assertEquals(PillKind.Success, kind)
    }

    @Test fun `captured maps to Success (Razorpay terminology)`() {
        val (text, kind) = paymentStatusChipTextAndKind("captured")
        assertEquals("CAPTURED", text)
        assertEquals(PillKind.Success, kind)
    }

    @Test fun `paid maps to Success`() {
        assertEquals(PillKind.Success, paymentStatusChipTextAndKind("paid").second)
    }

    @Test fun `success maps to Success`() {
        assertEquals(PillKind.Success, paymentStatusChipTextAndKind("success").second)
    }

    // ---- Danger bucket ----

    @Test fun `failed maps to Danger`() {
        val (text, kind) = paymentStatusChipTextAndKind("failed")
        assertEquals("FAILED", text)
        assertEquals(PillKind.Danger, kind)
    }

    @Test fun `cancelled (UK spelling) maps to Danger`() {
        // Razorpay typically emits "cancelled"; pin so the British
        // spelling stays in the matcher.
        assertEquals(PillKind.Danger, paymentStatusChipTextAndKind("cancelled").second)
    }

    @Test fun `canceled (US spelling) also maps to Danger`() {
        // Internal triggers sometimes use US spelling. Pin both.
        assertEquals(PillKind.Danger, paymentStatusChipTextAndKind("canceled").second)
    }

    // ---- Neutral fallback ----

    @Test fun `null status folds to UNKNOWN with Neutral kind`() {
        val (text, kind) = paymentStatusChipTextAndKind(null)
        // Pin the literal "UNKNOWN" so a stale row that lost its
        // column doesn't render an empty chip.
        assertEquals("UNKNOWN", text)
        assertEquals(PillKind.Neutral, kind)
    }

    @Test fun `unknown future status passes through uppercased with Neutral kind`() {
        val (text, kind) = paymentStatusChipTextAndKind("processing")
        assertEquals("PROCESSING", text)
        assertEquals(PillKind.Neutral, kind)
    }

    @Test fun `pending status (Razorpay in-flight) is Neutral not Success`() {
        // Critical — "pending" is in-flight, NOT terminal. Pin so a
        // future addition to the Success list doesn't accidentally
        // claim victory before the webhook confirms.
        assertEquals(PillKind.Neutral, paymentStatusChipTextAndKind("pending").second)
    }

    // ---- Case-insensitive match ----

    @Test fun `uppercase input still matches (case-folded lookup)`() {
        // The matcher lowercases before lookup; mixed case from a
        // hand-pasted Razorpay dashboard string still works.
        assertEquals(PillKind.Success, paymentStatusChipTextAndKind("COMPLETED").second)
        assertEquals(PillKind.Danger, paymentStatusChipTextAndKind("Failed").second)
    }

    @Test fun `text is always uppercase regardless of input case`() {
        // Visual emphasis — pin so a refactor that dropped uppercase()
        // would surface as a softer chip on the queue.
        assertEquals("COMPLETED", paymentStatusChipTextAndKind("completed").first)
        assertEquals("CAPTURED", paymentStatusChipTextAndKind("Captured").first)
        assertEquals("FAILED", paymentStatusChipTextAndKind("failed").first)
    }
}
