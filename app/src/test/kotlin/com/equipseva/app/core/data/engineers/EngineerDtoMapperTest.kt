package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the [EngineerDto] → [Engineer] mapper. Every nullable JSON field
 * carries server-side back-compat semantics (the columns rolled out one
 * by one across releases), so the mapper coerces missing/blank fields
 * to typed defaults rather than crashing the directory + KYC + nearby
 * screens. A regression that swapped any of these defaults would ripple
 * into every engineer-facing surface.
 */
class EngineerDtoMapperTest {

    private fun emptyDto(
        id: String = "e1",
        userId: String = "u1",
    ) = EngineerDto(id = id, userId = userId)

    @Test fun `all-null dto maps to sensible domain defaults`() {
        val engineer = emptyDto().toDomain()

        assertEquals("e1", engineer.id)
        assertEquals("u1", engineer.userId)
        assertNull(engineer.aadhaarNumber)
        assertFalse(engineer.aadhaarVerified)
        assertNull(engineer.panNumber)
        assertTrue(engineer.qualifications.isEmpty())
        assertTrue(engineer.specializations.isEmpty())
        assertTrue(engineer.brandsServiced.isEmpty())
        assertEquals(0, engineer.experienceYears)
        // serviceRadiusKm default: when the column is null on a legacy
        // row, the mapper falls back to 25km. Pinning the literal — a
        // server-side change to "no default" would break nearby search.
        assertEquals(25, engineer.serviceRadiusKm)
        assertNull(engineer.city)
        assertNull(engineer.state)
        assertEquals(VerificationStatus.Pending, engineer.verificationStatus)
        assertNull(engineer.verificationNotes)
        assertTrue(engineer.rejectedDocTypes.isEmpty())
        assertEquals(VerificationStatus.Pending, engineer.backgroundCheckStatus)
        assertTrue(engineer.certificates.isEmpty())
        assertNull(engineer.hourlyRate)
        assertNull(engineer.yearsExperience)
        assertTrue(engineer.serviceAreas.isEmpty())
        assertNull(engineer.bio)
        // isAvailable defaults TRUE so a legacy row without the column
        // is still surfaced on directory search. Catch a flip to false.
        assertTrue(engineer.isAvailable)
        assertNull(engineer.latitude)
        assertNull(engineer.longitude)
        assertNull(engineer.ratingAvg)
        assertNull(engineer.totalJobs)
        assertNull(engineer.completionRate)
    }

    @Test fun `blank string fields fold to null`() {
        // The KYC screen historically wrote empty strings; the mapper
        // normalises those to null so downstream `if (city != null)`
        // checks behave as expected.
        val dto = emptyDto().copy(
            aadhaarNumber = "   ",
            panNumber = "",
            city = "  ",
            state = "",
            verificationNotes = " ",
            bio = "   ",
        )
        val engineer = dto.toDomain()

        assertNull(engineer.aadhaarNumber)
        assertNull(engineer.panNumber)
        assertNull(engineer.city)
        assertNull(engineer.state)
        assertNull(engineer.verificationNotes)
        assertNull(engineer.bio)
    }

    @Test fun `non-blank string fields pass through verbatim`() {
        val dto = emptyDto().copy(
            aadhaarNumber = "1234-5678-9012",
            panNumber = "ABCDE1234F",
            city = "Bengaluru",
            state = "KA",
            verificationNotes = "Aadhaar photo unreadable",
            bio = "10 years on imaging modalities",
        )
        val engineer = dto.toDomain()

        assertEquals("1234-5678-9012", engineer.aadhaarNumber)
        assertEquals("ABCDE1234F", engineer.panNumber)
        assertEquals("Bengaluru", engineer.city)
        assertEquals("KA", engineer.state)
        assertEquals("Aadhaar photo unreadable", engineer.verificationNotes)
        assertEquals("10 years on imaging modalities", engineer.bio)
    }

    @Test fun `specializations storage-keys map to RepairEquipmentCategory entries`() {
        val dto = emptyDto().copy(
            specializations = listOf("imaging_radiology", "dental", "oncology"),
        )
        val engineer = dto.toDomain()

        assertEquals(
            listOf(
                RepairEquipmentCategory.ImagingRadiology,
                RepairEquipmentCategory.Dental,
                RepairEquipmentCategory.Oncology,
            ),
            engineer.specializations,
        )
    }

    @Test fun `unknown specialization key folds to Other instead of crashing`() {
        // Forward-compat: future server-side category additions render
        // as Other on older clients instead of dropping the row.
        val dto = emptyDto().copy(specializations = listOf("imaging_radiology", "future_xray"))
        val engineer = dto.toDomain()

        assertEquals(
            listOf(RepairEquipmentCategory.ImagingRadiology, RepairEquipmentCategory.Other),
            engineer.specializations,
        )
    }

    @Test fun `verification statuses round-trip storage keys`() {
        val pending = emptyDto().copy(
            verificationStatus = "pending",
            backgroundCheckStatus = "verified",
        ).toDomain()
        assertEquals(VerificationStatus.Pending, pending.verificationStatus)
        assertEquals(VerificationStatus.Verified, pending.backgroundCheckStatus)

        val rejected = emptyDto().copy(
            verificationStatus = "rejected",
            backgroundCheckStatus = "rejected",
        ).toDomain()
        assertEquals(VerificationStatus.Rejected, rejected.verificationStatus)
        assertEquals(VerificationStatus.Rejected, rejected.backgroundCheckStatus)
    }

    @Test fun `unknown verification key defaults to Pending not crash`() {
        val dto = emptyDto().copy(
            verificationStatus = "wat",
            backgroundCheckStatus = "also_wat",
        )
        val engineer = dto.toDomain()
        assertEquals(VerificationStatus.Pending, engineer.verificationStatus)
        assertEquals(VerificationStatus.Pending, engineer.backgroundCheckStatus)
    }

    @Test fun `aadhaarVerified false maps to false (no surprise null promotion)`() {
        val dto = emptyDto().copy(aadhaarVerified = false, isAvailable = false)
        val engineer = dto.toDomain()
        assertFalse(engineer.aadhaarVerified)
        assertFalse(engineer.isAvailable)
    }

    @Test fun `derived getters split certificates by type`() {
        val certs = listOf(
            EngineerCertificate(
                type = EngineerCertificate.TYPE_AADHAAR,
                path = "k/aadhaar.jpg",
                uploadedAt = "2026-04-01T00:00:00Z",
            ),
            EngineerCertificate(
                type = EngineerCertificate.TYPE_PAN,
                path = "k/pan.jpg",
                uploadedAt = "2026-04-02T00:00:00Z",
            ),
            EngineerCertificate(
                type = EngineerCertificate.TYPE_CERT,
                path = "k/cert-a.jpg",
                uploadedAt = "2026-04-03T00:00:00Z",
            ),
            EngineerCertificate(
                type = EngineerCertificate.TYPE_CERT,
                path = "k/cert-b.jpg",
                uploadedAt = "2026-04-04T00:00:00Z",
            ),
        )
        val engineer = emptyDto().copy(certificates = certs).toDomain()

        assertEquals("k/aadhaar.jpg", engineer.aadhaarDocPath)
        assertEquals("k/pan.jpg", engineer.panDocPath)
        assertEquals(listOf("k/cert-a.jpg", "k/cert-b.jpg"), engineer.certDocPaths)
    }

    @Test fun `aadhaarDocPath picks the LAST aadhaar upload when re-submitted`() {
        // KYC resubmission appends; UI rehydration must show the
        // newest upload, not the rejected one.
        val certs = listOf(
            EngineerCertificate(
                type = EngineerCertificate.TYPE_AADHAAR,
                path = "k/aadhaar-v1.jpg",
                uploadedAt = "2026-04-01T00:00:00Z",
            ),
            EngineerCertificate(
                type = EngineerCertificate.TYPE_AADHAAR,
                path = "k/aadhaar-v2.jpg",
                uploadedAt = "2026-04-10T00:00:00Z",
            ),
        )
        val engineer = emptyDto().copy(certificates = certs).toDomain()
        assertEquals("k/aadhaar-v2.jpg", engineer.aadhaarDocPath)
    }
}
