package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the two pure helpers powering the buyer KYC founder queue:
 *  - `founderPrettyBuyerDocType` — compact label for the docType chip.
 *  - `founderParseSignedKycPath` — pulls the storage path back out of a
 *    persisted `/object/sign/...` URL so the VM can mint a fresh
 *    short-lived signed URL on tap.
 */
class FounderBuyerKycLogicTest {

    @Test fun `known doc type keys map to compact labels`() {
        // Each branch of the when — the founder pill is tiny so the
        // long-form name from postgres doesn't fit.
        assertEquals("Shop Reg", founderPrettyBuyerDocType("shop_registration"))
        assertEquals("GST", founderPrettyBuyerDocType("gst"))
        assertEquals("Drug Lic", founderPrettyBuyerDocType("drug_license"))
        assertEquals("MCI", founderPrettyBuyerDocType("mci"))
        assertEquals("DCI", founderPrettyBuyerDocType("dci"))
        assertEquals("Medical ID", founderPrettyBuyerDocType("medical_id"))
    }

    @Test fun `unknown doc type falls through verbatim`() {
        // A new enum value from the backend shouldn't disappear from the
        // UI — falling through to the raw key keeps the chip honest
        // until the front-end is updated.
        assertEquals("future_kind", founderPrettyBuyerDocType("future_kind"))
        assertEquals("", founderPrettyBuyerDocType(""))
    }

    @Test fun `parse extracts the storage path from a valid signed URL`() {
        // Real-world layout: project + /storage/v1/object/sign/<bucket>/<path>?token=...
        val url = "https://proj.supabase.co/storage/v1/object/sign/kyc-docs/users/abc/shop.jpg?token=eyJ"
        assertEquals("users/abc/shop.jpg", founderParseSignedKycPath(url, "kyc-docs"))
    }

    @Test fun `parse drops the query string but keeps nested folders`() {
        val url = "/object/sign/kyc-docs/a/b/c/d.pdf?token=x"
        assertEquals("a/b/c/d.pdf", founderParseSignedKycPath(url, "kyc-docs"))
    }

    @Test fun `parse returns null when the bucket marker is missing`() {
        // Caller falls back to the persisted URL on null — never crash
        // on a malformed legacy row.
        assertNull(founderParseSignedKycPath("https://example.com/random/path.pdf", "kyc-docs"))
        assertNull(founderParseSignedKycPath("", "kyc-docs"))
    }

    @Test fun `parse uses the supplied bucket name not a hard-coded constant`() {
        // Defends against accidental coupling — if someone hard-codes
        // "kyc-docs" in the helper, this swap to a different bucket
        // would silently return null.
        val url = "/object/sign/category-images/spare/x.png?token=y"
        assertEquals(
            "spare/x.png",
            founderParseSignedKycPath(url, "category-images"),
        )
    }

    @Test fun `parse with no query string keeps the full tail`() {
        // Older rows occasionally lack the ?token suffix (renewed signed
        // URLs sometimes drop it on certain Supabase versions); make
        // sure substringBefore doesn't truncate when there's no '?'.
        val url = "/object/sign/kyc-docs/users/x/doc.pdf"
        assertEquals("users/x/doc.pdf", founderParseSignedKycPath(url, "kyc-docs"))
    }
}
