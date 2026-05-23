package com.equipseva.app.features.kyc

import com.equipseva.app.core.data.engineers.EngineerCertificate
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the doc-type → user-facing label mapping used in KYC upload /
 * failure copy ("Aadhaar uploaded", "PAN failed", "certificate
 * uploaded"). The mapping reads the [EngineerCertificate] type
 * constants verbatim, so a regression here would surface as a "?"
 * placeholder in the user's snackbar.
 */
class KycDocTypeLabelTest {

    @Test fun `aadhaar type renders Aadhaar`() {
        assertEquals("Aadhaar", docTypeLabel(EngineerCertificate.TYPE_AADHAAR))
    }

    @Test fun `pan type renders PAN`() {
        assertEquals("PAN", docTypeLabel(EngineerCertificate.TYPE_PAN))
    }

    @Test fun `cert type renders the lowercase certificate copy`() {
        // Lowercase intentional — the copy strings read like
        // "Could not upload certificate" / "certificate uploaded",
        // so the label slots into a sentence rather than a title.
        assertEquals("certificate", docTypeLabel(EngineerCertificate.TYPE_CERT))
    }

    @Test fun `unknown type falls through to the raw string`() {
        // Forward-compat: if a future doc type is added without an
        // updated label entry, the snackbar shows the storage key
        // (ugly but truthful) instead of crashing.
        assertEquals("future_doc", docTypeLabel("future_doc"))
    }

    @Test fun `empty type falls through to empty string`() {
        // Defensive — a blank doc type shouldn't NPE on label lookup.
        assertEquals("", docTypeLabel(""))
    }
}
