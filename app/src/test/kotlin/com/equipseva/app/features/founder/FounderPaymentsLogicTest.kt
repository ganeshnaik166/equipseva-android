package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the payment-status → PillKind bucketing. Razorpay and our
 * in-house orders table use different success vocabularies (captured /
 * paid / completed / success) so they must all collapse to the green
 * pill. Explicit failures collapse to red. Everything else — pending,
 * created, refunded, "unknown" — stays neutral so the founder UI
 * doesn't fake confidence about an in-flight payment.
 */
class FounderPaymentsLogicTest {

    @Test fun `success vocabulary collapses to Success`() {
        // Each of the four success synonyms — losing one in a refactor
        // would silently demote successful orders to neutral.
        assertEquals(PillKind.Success, founderPaymentStatusKind("completed"))
        assertEquals(PillKind.Success, founderPaymentStatusKind("captured"))
        assertEquals(PillKind.Success, founderPaymentStatusKind("paid"))
        assertEquals(PillKind.Success, founderPaymentStatusKind("success"))
    }

    @Test fun `failure vocabulary collapses to Danger`() {
        // British vs American spelling for cancelled — keep both.
        assertEquals(PillKind.Danger, founderPaymentStatusKind("failed"))
        assertEquals(PillKind.Danger, founderPaymentStatusKind("cancelled"))
        assertEquals(PillKind.Danger, founderPaymentStatusKind("canceled"))
    }

    @Test fun `unknown intermediate states stay Neutral`() {
        // Pending / created / refunded / "unknown" all surface neutral —
        // we never want to imply success or failure for a status the
        // founder hasn't explicitly mapped.
        assertEquals(PillKind.Neutral, founderPaymentStatusKind("pending"))
        assertEquals(PillKind.Neutral, founderPaymentStatusKind("created"))
        assertEquals(PillKind.Neutral, founderPaymentStatusKind("refunded"))
        assertEquals(PillKind.Neutral, founderPaymentStatusKind("unknown"))
        assertEquals(PillKind.Neutral, founderPaymentStatusKind(""))
    }

    @Test fun `helper expects already-lowercased input`() {
        // The wrapping composable does the lowercasing, so an uppercase
        // string is not a known token and should bucket neutral. This
        // pins the contract — if you want the helper to lowercase
        // itself, update both the test and the call-site.
        assertEquals(PillKind.Neutral, founderPaymentStatusKind("PAID"))
        assertEquals(PillKind.Neutral, founderPaymentStatusKind("Failed"))
    }
}
