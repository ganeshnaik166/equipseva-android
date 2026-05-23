package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the buyer-KYC doc-type chip labels shown on the founder review
 * queue. Two notes:
 *
 *   1) `Shop Reg` is deliberately abbreviated — the chip is rendered
 *      next to ~3 others in a row and the unabbreviated "Shop
 *      Registration" wraps on small phones.
 *   2) The fallback returns the raw key verbatim so a server-side
 *      addition still shows *something* (even if it's snake_case) until
 *      this map is extended. Caught here so the abbreviations don't
 *      drift silently.
 */
class PrettyDocTypeTest {

    @Test fun `known doc-type keys render the abbreviated label`() {
        assertEquals("Shop Reg", prettyDocType("shop_registration"))
        assertEquals("GST", prettyDocType("gst"))
        assertEquals("Drug Lic", prettyDocType("drug_license"))
        assertEquals("MCI", prettyDocType("mci"))
        assertEquals("DCI", prettyDocType("dci"))
        assertEquals("Medical ID", prettyDocType("medical_id"))
    }

    @Test fun `unknown doc-type falls through to the raw key`() {
        // Forward-compat: surfaces the column name unmangled so the
        // founder can still triage; explicit per-key abbreviation is
        // added at the next product review.
        assertEquals("future_doc", prettyDocType("future_doc"))
    }

    @Test fun `the mapping is case-sensitive on storage keys`() {
        // The server-side enum is lowercase; uppercased input is not
        // a valid key and must not match. Pin so a defensive
        // `lowercase()` doesn't silently get added (would hide real
        // bugs where the wire payload differs).
        assertEquals("GST", prettyDocType("gst"))
        assertEquals("GST_UPPER", prettyDocType("GST_UPPER"))
    }
}
