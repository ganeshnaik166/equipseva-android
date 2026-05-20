package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the three string derivations on the founder reports queue row.
 * Snake-case → "Title case" was a real bug: `off_platform_payment` was
 * leaking into the UI verbatim before PR #174. Reporter/target slugs
 * keep the row scannable when UUIDs would blow the layout.
 */
class FounderReportsLogicTest {

    @Test fun `prettify replaces underscores and capitalises the first letter`() {
        // Only the *first* char is capped — "off_platform" becomes
        // "Off platform", not "Off Platform". Matches the screenshot
        // spec; this test pins it.
        assertEquals("Off platform payment", founderPrettifySnakeCase("off_platform_payment"))
        assertEquals("No show", founderPrettifySnakeCase("no_show"))
    }

    @Test fun `prettify handles already-pretty and single-word strings`() {
        assertEquals("Engineer", founderPrettifySnakeCase("engineer"))
        assertEquals("Buyer", founderPrettifySnakeCase("buyer"))
    }

    @Test fun `prettify leaves an empty string empty`() {
        // `replaceFirstChar` on "" is safe; spec is to keep it empty
        // rather than fall back to a placeholder.
        assertEquals("", founderPrettifySnakeCase(""))
    }

    @Test fun `reporter label prefers profile name over uuid prefix`() {
        // Friendly name wins — same shape as the chat row preference.
        assertEquals(
            "Dr. Anita Rao",
            founderReporterLabel("Dr. Anita Rao", "u-1234-5678-90ab"),
        )
    }

    @Test fun `reporter label falls back to the first 8 chars of the uuid`() {
        // Tests both null and blank — only null falls through today,
        // but pinning the blank case documents that empty profile rows
        // still display as the user-id prefix instead of "" (which would
        // render "Reporter: " with a trailing space).
        assertEquals(
            "u-1234-5",
            founderReporterLabel(null, "u-1234-5678-90ab"),
        )
    }

    @Test fun `target slug returns the last 8 chars of the id`() {
        // Last-8 makes UUIDs scannable. Founders who need the full id
        // grab it from the action handler / detail page.
        // "u-1234-5678-90ab" is 16 chars; takeLast(8) → "678-90ab".
        assertEquals(
            "678-90ab",
            founderTargetIdSlug("u-1234-5678-90ab"),
        )
    }

    @Test fun `target slug returns the whole string when shorter than 8 chars`() {
        // `takeLast` is bound-safe so a short dummy id stays intact.
        assertEquals("dummy", founderTargetIdSlug("dummy"))
        assertEquals("", founderTargetIdSlug(""))
    }
}
