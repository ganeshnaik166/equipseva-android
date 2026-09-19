package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * Pins the ilike-wildcard escape used on the repair-feed search box.
 * Postgres ilike treats `%` and `_` as wildcards; without escaping,
 * a user typing "100%" or "model_x" produces an over-broad query
 * (matches every row).
 *
 * The backslash must be escaped FIRST so the percent/underscore
 * replacements don't double-escape the backslashes they introduce.
 * A regression in ordering (escape percent first, then backslash)
 * would mangle every search term to "\\\\%" — Postgres would match
 * literal backslashes, not the user's percent sign.
 */
class SanitizeForIlikeTest {

    @Test fun `plain text passes through unchanged`() {
        assertEquals("hello", sanitizeForIlike("hello"))
        assertEquals("Model X-200", sanitizeForIlike("Model X-200"))
    }

    @Test fun `empty string round-trips empty`() {
        assertEquals("", sanitizeForIlike(""))
    }

    @Test fun `percent is escaped`() {
        assertEquals("100\\%", sanitizeForIlike("100%"))
    }

    @Test fun `underscore is escaped`() {
        assertEquals("model\\_x", sanitizeForIlike("model_x"))
    }

    @Test fun `backslash is escaped`() {
        // Single backslash must become double-backslash so the
        // server-side ilike literal still parses as one backslash.
        assertEquals("a\\\\b", sanitizeForIlike("a\\b"))
    }

    @Test fun `backslash escape runs BEFORE percent or underscore escape`() {
        // Pin the ordering: the percent escape introduces a backslash,
        // and if backslash were escaped after, that introduced
        // backslash would be doubled into "\\\\" leaving an unwanted
        // literal `\\` in the search term.
        assertEquals("\\\\\\%", sanitizeForIlike("\\%"))
        assertEquals("\\\\\\_", sanitizeForIlike("\\_"))
    }

    @Test fun `multiple wildcards in one term all escape`() {
        assertEquals(
            "100\\% off model\\_x\\%",
            sanitizeForIlike("100% off model_x%"),
        )
    }

    @Test fun `consecutive wildcards each escape`() {
        assertEquals("\\%\\%\\%", sanitizeForIlike("%%%"))
    }

    @Test fun `unicode and special chars not in the wildcard set pass through`() {
        assertEquals("Bengaluru ₹", sanitizeForIlike("Bengaluru ₹"))
        assertEquals("héllo", sanitizeForIlike("héllo"))
    }

    // A comma or parenthesis ends a value inside PostgREST's `or=(col.ilike.…)`
    // grammar and a double quote opens a quoted one, so a search for
    // "GE, Philips (new)" used to come back as PGRST100 with an errored feed.
    @Test fun `PostgREST or-grammar delimiters are neutralised`() {
        val out = sanitizeForIlike("GE, Philips (new) \"x\"")
        assertFalse(out, out.any { it == ',' || it == '(' || it == ')' || it == '"' })
        assertEquals("GE  Philips  new   x ", out)
    }
}
