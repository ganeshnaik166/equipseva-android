package com.equipseva.app.features.kyc

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IsKycSubmittedTest {

    @Test fun `all three uploaded returns true`() {
        assertTrue(
            isKycSubmitted(
                aadhaarDocPath = "aadhaar.jpg",
                panDocPath = "pan.jpg",
                certDocPaths = listOf("cert1.jpg"),
            ),
        )
    }

    @Test fun `missing aadhaar blocks submission`() {
        assertFalse(
            isKycSubmitted(null, "pan.jpg", listOf("cert.jpg")),
        )
        assertFalse(
            isKycSubmitted("", "pan.jpg", listOf("cert.jpg")),
        )
        assertFalse(
            isKycSubmitted("   ", "pan.jpg", listOf("cert.jpg")),
        )
    }

    @Test fun `missing pan blocks submission`() {
        assertFalse(
            isKycSubmitted("aadhaar.jpg", null, listOf("cert.jpg")),
        )
        assertFalse(
            isKycSubmitted("aadhaar.jpg", "", listOf("cert.jpg")),
        )
    }

    @Test fun `empty cert list blocks submission`() {
        // Critical pin — at least one certificate required.
        assertFalse(
            isKycSubmitted("aadhaar.jpg", "pan.jpg", emptyList()),
        )
    }

    @Test fun `multiple certs allowed`() {
        assertTrue(
            isKycSubmitted(
                "aadhaar.jpg",
                "pan.jpg",
                listOf("cert1.jpg", "cert2.jpg", "cert3.jpg"),
            ),
        )
    }

    @Test fun `all three missing returns false`() {
        assertFalse(
            isKycSubmitted(null, null, emptyList()),
        )
    }

    @Test fun `Aadhaar verified but no PAN or cert blocks (regression history)`() {
        // Critical regression target — the previous aadhaarVerified
        // proxy let this case through and the banner claimed
        // "submitted" while the row was still mid-edit.
        assertFalse(
            isKycSubmitted("aadhaar.jpg", null, emptyList()),
        )
    }
}
