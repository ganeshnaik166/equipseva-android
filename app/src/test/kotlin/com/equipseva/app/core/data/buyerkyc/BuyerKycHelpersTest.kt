package com.equipseva.app.core.data.buyerkyc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Buyer KYC writes the doc to storage under a key like
 * `{uid}/buyer_kyc_{doc_type}.{ext}` — a wrong extension creates a
 * mismatched key the founder console can't preview, and a missing GST
 * check lets the form submit with a blank GSTIN that fails server-side
 * with a generic "couldn't save" toast.
 */
class BuyerKycHelpersTest {

    @Test fun `mime extension maps every documented type`() {
        assertEquals("pdf", buyerKycMimeExtension("application/pdf"))
        assertEquals("png", buyerKycMimeExtension("image/png"))
        assertEquals("webp", buyerKycMimeExtension("image/webp"))
        assertEquals("jpg", buyerKycMimeExtension("image/jpeg"))
    }

    @Test fun `mime extension lowercases input`() {
        // SAF on some devices returns "Image/PNG" — pin that we
        // normalise before matching.
        assertEquals("png", buyerKycMimeExtension("Image/PNG"))
        assertEquals("pdf", buyerKycMimeExtension("APPLICATION/PDF"))
    }

    @Test fun `unknown mime defaults to jpg`() {
        // UploadValidator rejects unknown mimes earlier, but the key
        // builder still has to pick *some* extension.
        assertEquals("jpg", buyerKycMimeExtension("image/heic"))
        assertEquals("jpg", buyerKycMimeExtension(""))
        assertEquals("jpg", buyerKycMimeExtension("application/octet-stream"))
    }

    @Test fun `GST number 15-char canonical shape passes`() {
        // Real GSTIN is exactly 15 chars (state code + PAN + entity).
        assertTrue(isPlausibleGstNumber("27ABCDE1234F1Z5"))
    }

    @Test fun `GST number widened window accepts 10 to 20 chars`() {
        // Deliberately loose so buyers can paste UDYAM / UAM numbers
        // here too — admin reviews the doc anyway.
        assertTrue(isPlausibleGstNumber("0123456789"))
        assertTrue(isPlausibleGstNumber("01234567890123456789"))
    }

    @Test fun `GST shorter than 10 fails`() {
        assertFalse(isPlausibleGstNumber("123456789"))
    }

    @Test fun `GST longer than 20 fails`() {
        assertFalse(isPlausibleGstNumber("012345678901234567890"))
    }

    @Test fun `null and blank GST fail`() {
        assertFalse(isPlausibleGstNumber(null))
        assertFalse(isPlausibleGstNumber(""))
        assertFalse(isPlausibleGstNumber("   "))
    }
}
