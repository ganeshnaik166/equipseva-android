package com.equipseva.app.features.repair

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanSubmitEngineerResponseTest {

    @Test fun `10-char response enables submit when not submitting`() {
        // Exactly 10 chars — inclusive boundary.
        assertTrue(canSubmitEngineerResponse("1234567890", submitting = false))
    }

    @Test fun `9-char response blocks (under 10-char floor)`() {
        // Critical pin — floor is >= 10. "yes" / "ok" would be
        // useless evidence for admin's release-vs-refund decision.
        assertFalse(canSubmitEngineerResponse("123456789", submitting = false))
    }

    @Test fun `whitespace-padded short response blocks (trim then check)`() {
        // Pin .trim().length — whitespace-only or padded shouldn't
        // enable submit.
        assertFalse(canSubmitEngineerResponse("   ok   ", submitting = false))
    }

    @Test fun `whitespace-only blocks regardless of total length`() {
        // 20 chars of whitespace trims to 0 → block.
        assertFalse(canSubmitEngineerResponse("                    ", submitting = false))
    }

    @Test fun `submitting blocks regardless of valid response`() {
        // Prevents double-tap during in-flight POST.
        assertFalse(
            canSubmitEngineerResponse(
                "This is a perfectly fine substantive response",
                submitting = true,
            ),
        )
    }

    @Test fun `substantive response enables submit`() {
        assertTrue(
            canSubmitEngineerResponse(
                "Replaced the PCB on-site, hospital signed off",
                submitting = false,
            ),
        )
    }

    @Test fun `empty response blocks`() {
        assertFalse(canSubmitEngineerResponse("", submitting = false))
    }
}
