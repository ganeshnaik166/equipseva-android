package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Engineer is the spine of KYC + the engineer self-profile + the directory.
 * The defensive defaults here are load-bearing: a null `service_radius_km`
 * must fall back to the v1 default (25 km) so the feed query has a sensible
 * radius even before the engineer fills it in, and null `is_available`
 * must default to true so a freshly-created engineer is visible.
 */
class EngineerDtoTest {

    @Test fun `defaults backfill missing scalar columns`() {
        val domain = EngineerDto(
            id = "e1",
            userId = "u1",
        ).toDomain()

        assertEquals(0, domain.experienceYears)
        assertEquals(25, domain.serviceRadiusKm)
        assertFalse(domain.aadhaarVerified)
        assertTrue(domain.isAvailable)
        assertEquals(VerificationStatus.Pending, domain.verificationStatus)
        assertEquals(VerificationStatus.Pending, domain.backgroundCheckStatus)
        // Stat columns stay null when absent (we don't fabricate zeros for
        // engineers who haven't done a job yet — the directory hides the
        // rating chip in that case).
        assertNull(domain.ratingAvg)
        assertNull(domain.totalJobs)
        assertNull(domain.completionRate)
    }

    @Test fun `blank strings collapse to null on identity + location fields`() {
        val domain = EngineerDto(
            id = "e1",
            userId = "u1",
            aadhaarNumber = "  ",
            panNumber = "",
            city = "  ",
            state = "",
            bio = "   ",
            verificationNotes = "  ",
        ).toDomain()

        assertNull(domain.aadhaarNumber)
        assertNull(domain.panNumber)
        assertNull(domain.city)
        assertNull(domain.state)
        assertNull(domain.bio)
        assertNull(domain.verificationNotes)
    }

    @Test fun `specializations map onto RepairEquipmentCategory enums`() {
        val domain = EngineerDto(
            id = "e1",
            userId = "u1",
            specializations = listOf("imaging_radiology", "dental", "totally_made_up"),
        ).toDomain()

        assertEquals(
            listOf(
                RepairEquipmentCategory.ImagingRadiology,
                RepairEquipmentCategory.Dental,
                RepairEquipmentCategory.Other,
            ),
            domain.specializations,
        )
    }

    @Test fun `cert path helpers find the latest matching certificate by type`() {
        val aadhaarOld = EngineerCertificate(
            type = EngineerCertificate.TYPE_AADHAAR,
            path = "aadhaar/v1.jpg",
            uploadedAt = "2026-05-01T09:00:00Z",
        )
        val aadhaarNew = aadhaarOld.copy(path = "aadhaar/v2.jpg")
        val pan = EngineerCertificate(
            type = EngineerCertificate.TYPE_PAN,
            path = "pan/p1.jpg",
            uploadedAt = "2026-05-04T09:00:00Z",
        )
        val cert1 = EngineerCertificate(
            type = EngineerCertificate.TYPE_CERT,
            path = "cert/c1.pdf",
            uploadedAt = "2026-05-02T09:00:00Z",
        )
        val cert2 = cert1.copy(path = "cert/c2.pdf")

        val domain = EngineerDto(
            id = "e1",
            userId = "u1",
            certificates = listOf(aadhaarOld, cert1, aadhaarNew, pan, cert2),
        ).toDomain()

        // lastOrNull semantics — most recent re-upload wins for the
        // single-slot types (KYC re-upload flow PR #166 depends on this).
        assertEquals("aadhaar/v2.jpg", domain.aadhaarDocPath)
        assertEquals("pan/p1.jpg", domain.panDocPath)
        // Cert list keeps insertion order and includes every entry.
        assertEquals(listOf("cert/c1.pdf", "cert/c2.pdf"), domain.certDocPaths)
        assertNull(domain.selfieDocPath)
    }

    @Test fun `VerificationStatus unknown key falls back to Pending`() {
        // Forwards-compat — a new server-side status shouldn't lock the user
        // out of seeing their KYC state.
        assertEquals(VerificationStatus.Pending, VerificationStatus.fromKey(null))
        assertEquals(VerificationStatus.Pending, VerificationStatus.fromKey("escalated"))
        assertEquals(VerificationStatus.Verified, VerificationStatus.fromKey("verified"))
        assertEquals(VerificationStatus.Rejected, VerificationStatus.fromKey("rejected"))
    }

    @Test fun `rejected docs list passes through unchanged`() {
        // Re-upload flow gates each slot on whether its type is in the
        // rejected_doc_types array. Order isn't load-bearing but presence is.
        val domain = EngineerDto(
            id = "e1",
            userId = "u1",
            verificationStatus = "rejected",
            rejectedDocTypes = listOf("aadhaar", "pan"),
        ).toDomain()

        assertEquals(listOf("aadhaar", "pan"), domain.rejectedDocTypes)
        assertEquals(VerificationStatus.Rejected, domain.verificationStatus)
    }
}
