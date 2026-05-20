package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The engineer feed's search ?q= falls into a Postgres ILIKE filter on
 * issue_description / brand / model. Without escaping, the metacharacters
 * `%` and `_` (and the escape backslash itself) leak into the SQL pattern
 * and let a malicious / accidental query match unrelated rows. Pin the
 * escaping behaviour.
 */
class IlikeSanitizerTest {

    @Test fun `plain text passes through unchanged`() {
        assertEquals("MRI gantry", "MRI gantry".sanitizeForIlike())
    }

    @Test fun `percent is escaped`() {
        // "100%" without escape matches "100" followed by anything.
        assertEquals("100\\%", "100%".sanitizeForIlike())
    }

    @Test fun `underscore is escaped`() {
        // Bare "_" matches any single character in ILIKE.
        assertEquals("model\\_v2", "model_v2".sanitizeForIlike())
    }

    @Test fun `backslash is escaped first so subsequent escapes survive intact`() {
        // The replace chain must escape backslash first, otherwise the
        // backslashes we add for % and _ would be re-escaped into literal
        // `\\\\%` etc. This test catches a reordering of the chain.
        assertEquals("a\\\\b", "a\\b".sanitizeForIlike())
        assertEquals("a\\\\\\%b", "a\\%b".sanitizeForIlike())
        assertEquals("a\\\\\\_b", "a\\_b".sanitizeForIlike())
    }

    @Test fun `combined metacharacters are all escaped`() {
        assertEquals(
            "\\%foo\\_bar\\\\baz\\%",
            "%foo_bar\\baz%".sanitizeForIlike(),
        )
    }

    @Test fun `empty and whitespace-only strings round-trip`() {
        assertEquals("", "".sanitizeForIlike())
        assertEquals("   ", "   ".sanitizeForIlike())
    }
}
