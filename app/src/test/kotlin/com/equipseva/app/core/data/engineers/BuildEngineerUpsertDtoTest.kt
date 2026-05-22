package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the KYC-upsert payload composition. Three regions worth
 * defending:
 *
 *   1) Blank-string-to-null folding on every nullable text field so
 *      Postgrest doesn't write empty strings into columns that have a
 *      non-null default (would clobber legacy data).
 *   2) Empty-collection-to-null folding for qualifications /
 *      specializations / certificates so an in-progress KYC re-submit
 *      doesn't blank out previously-uploaded values just because the
 *      user is editing a different step.
 *   3) The `aadhaar_verified` flag is positive-only — set true only
 *      when a new Aadhaar doc was uploaded this round, never set
 *      false on the wire (the column is monotonic — once verified it
 *      stays verified; a re-submit shouldn't downgrade).
 *   4) `verification_status` is omitted unless the engineer is
 *      explicitly re-entering review (rejected → pending re-submit).
 *      Otherwise the column is preserved server-side.
 */
class BuildEngineerUpsertDtoTest {

    private fun minimal(
        userId: String = "u1",
        aadhaarNumber: String? = null,
        panNumber: String? = null,
        qualifications: List<String> = emptyList(),
        specializations: List<RepairEquipmentCategory> = emptyList(),
        city: String? = null,
        state: String? = null,
        certificates: List<EngineerCertificate> = emptyList(),
        aadhaarUploaded: Boolean = false,
        resetVerificationToPending: Boolean = false,
    ) = buildEngineerUpsertDto(
        userId = userId,
        aadhaarNumber = aadhaarNumber,
        panNumber = panNumber,
        qualifications = qualifications,
        specializations = specializations,
        experienceYears = 5,
        serviceRadiusKm = 25,
        city = city,
        state = state,
        latitude = null,
        longitude = null,
        certificates = certificates,
        aadhaarUploaded = aadhaarUploaded,
        resetVerificationToPending = resetVerificationToPending,
    )

    @Test fun `minimal input folds every nullable to null`() {
        val dto = minimal()
        assertEquals("u1", dto.userId)
        assertNull(dto.aadhaarNumber)
        assertNull(dto.panNumber)
        assertNull(dto.qualifications)
        assertNull(dto.specializations)
        assertNull(dto.city)
        assertNull(dto.state)
        assertNull(dto.certificates)
        // aadhaarVerified is positive-only — omit when false.
        assertNull(dto.aadhaarVerified)
        // verification_status omitted unless explicit re-submit.
        assertNull(dto.verificationStatus)
        assertEquals(5, dto.experienceYears)
        assertEquals(25, dto.serviceRadiusKm)
    }

    @Test fun `blank strings fold to null`() {
        val dto = minimal(
            aadhaarNumber = "  ",
            panNumber = "",
            city = "  ",
            state = "",
        )
        assertNull(dto.aadhaarNumber)
        assertNull(dto.panNumber)
        assertNull(dto.city)
        assertNull(dto.state)
    }

    @Test fun `non-blank strings pass through`() {
        val dto = minimal(
            aadhaarNumber = "234123412346",
            panNumber = "ABCDE1234F",
            city = "Bengaluru",
            state = "KA",
        )
        assertEquals("234123412346", dto.aadhaarNumber)
        assertEquals("ABCDE1234F", dto.panNumber)
        assertEquals("Bengaluru", dto.city)
        assertEquals("KA", dto.state)
    }

    @Test fun `empty qualifications list folds to null (preserves server-side value)`() {
        val dto = minimal(qualifications = emptyList())
        assertNull(dto.qualifications)
    }

    @Test fun `non-empty qualifications list passes through`() {
        val dto = minimal(qualifications = listOf("BSc Biomed", "Diploma EE"))
        assertEquals(listOf("BSc Biomed", "Diploma EE"), dto.qualifications)
    }

    @Test fun `specializations map to storage keys`() {
        val dto = minimal(
            specializations = listOf(
                RepairEquipmentCategory.ImagingRadiology,
                RepairEquipmentCategory.Dental,
            ),
        )
        assertEquals(listOf("imaging_radiology", "dental"), dto.specializations)
    }

    @Test fun `empty specializations list folds to null`() {
        val dto = minimal(specializations = emptyList())
        assertNull(dto.specializations)
    }

    @Test fun `empty certificates list folds to null (preserves prior uploads)`() {
        val dto = minimal(certificates = emptyList())
        assertNull(dto.certificates)
    }

    @Test fun `non-empty certificates list passes through`() {
        val cert = EngineerCertificate(
            type = EngineerCertificate.TYPE_AADHAAR,
            path = "k/a.jpg",
            uploadedAt = "2026-05-21T10:00:00Z",
        )
        val dto = minimal(certificates = listOf(cert))
        assertEquals(listOf(cert), dto.certificates)
    }

    // ---- aadhaarVerified flag ----

    @Test fun `aadhaarUploaded false sets aadhaarVerified to null (no downgrade)`() {
        // Critical: the wire payload must NOT carry false here.
        // Postgrest would write false into the column and downgrade
        // a previously-verified engineer on a profile edit.
        val dto = minimal(aadhaarUploaded = false)
        assertNull(dto.aadhaarVerified)
    }

    @Test fun `aadhaarUploaded true sets aadhaarVerified to true`() {
        val dto = minimal(aadhaarUploaded = true)
        assertEquals(true, dto.aadhaarVerified)
    }

    // ---- verification_status reset ----

    @Test fun `resetVerificationToPending false omits the column`() {
        val dto = minimal(resetVerificationToPending = false)
        assertNull(dto.verificationStatus)
    }

    @Test fun `resetVerificationToPending true writes the pending storage key`() {
        val dto = minimal(resetVerificationToPending = true)
        assertEquals(VerificationStatus.Pending.storageKey, dto.verificationStatus)
        assertEquals("pending", dto.verificationStatus)
    }

    @Test fun `lat lng pass through unchanged`() {
        val dto = buildEngineerUpsertDto(
            userId = "u1",
            aadhaarNumber = null,
            panNumber = null,
            qualifications = emptyList(),
            specializations = emptyList(),
            experienceYears = 5,
            serviceRadiusKm = 25,
            city = null,
            state = null,
            latitude = 12.97,
            longitude = 77.59,
            certificates = emptyList(),
            aadhaarUploaded = false,
            resetVerificationToPending = false,
        )
        assertEquals(12.97, dto.latitude!!, 0.001)
        assertEquals(77.59, dto.longitude!!, 0.001)
    }
}
