package com.equipseva.app.features.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the title/body rendering gates on a notification row.
 *
 * Critical invariant: when the title is blank, body is promoted up
 * to the title slot AND the body subline is hidden — otherwise the
 * body would double-print on the row.
 */
class NotificationRowTextHelpersTest {

    // ---- notificationRowTitleText ------------------------------------

    @Test fun `non-blank title wins`() {
        assertEquals(
            "New repair request",
            notificationRowTitleText("New repair request", "An MRI scan is broken at Apollo"),
        )
    }

    @Test fun `blank title promotes body to title slot`() {
        // Legacy server rows store body only; pin so the row still
        // surfaces readable text in the primary position.
        assertEquals(
            "An MRI scan is broken at Apollo",
            notificationRowTitleText("", "An MRI scan is broken at Apollo"),
        )
    }

    @Test fun `whitespace-only title also promotes body via ifBlank`() {
        // Critical pin — ifBlank, not `.ifEmpty` or `?:`. Whitespace-
        // only title (legacy backfill) should still promote.
        assertEquals(
            "Body content",
            notificationRowTitleText("   ", "Body content"),
        )
    }

    @Test fun `both blank still returns blank (caller can hide row)`() {
        assertEquals("", notificationRowTitleText("", ""))
    }

    // ---- notificationRowShouldShowBody -------------------------------

    @Test fun `body shown when both title and body non-blank`() {
        assertTrue(
            notificationRowShouldShowBody("Title", "Body"),
        )
    }

    @Test fun `body hidden when title is blank (body was promoted to title)`() {
        // Critical pin — prevents double-print.
        assertFalse(
            notificationRowShouldShowBody("", "Body content"),
        )
        assertFalse(
            notificationRowShouldShowBody("   ", "Body content"),
        )
    }

    @Test fun `body hidden when body is blank`() {
        assertFalse(
            notificationRowShouldShowBody("Title only", ""),
        )
        assertFalse(
            notificationRowShouldShowBody("Title only", "   "),
        )
    }

    @Test fun `body hidden when both are blank`() {
        assertFalse(
            notificationRowShouldShowBody("", ""),
        )
    }
}
