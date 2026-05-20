package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The KYC upsert payload bakes in three load-bearing conventions:
 * blank-strings-collapse-to-null (so server CHECKs fire on missing rather
 * than literal ""), empty-list-collapses-to-null (so a partial edit can't
 * overwrite a populated qualifications/certificates array with []), and the
 * one-way Aadhaar verification flag (we only ever set it to true; only the
 * server admin flow flips it back). All three branches need pinning.
 */
class EngineerUpsertDtoTest {

    private fun build(
        userId: String = "u1",
        aadhaarNumber: String? = null,
        panNumber: String? = null,
        qualifications: List<String> = emptyList(),
        specializations: List<RepairEquipmentCategory> = emptyList(),
        experienceYears: Int = 0,
        serviceRadiusKm: Int = 25,
        city: String? = null,
        state: String? = null,
        latitude: Double? = null,
        longitude: Double? = null,
        certificates: List<EngineerCertificate> = emptyList(),
        aadhaarUploaded: Boolean = false,
        resetVerificationToPending: Boolean = false,
    ) = buildEngineerUpsertDto(
        userId = userId,
        aadhaarNumber = aadhaarNumber,
        panNumber = panNumber,
        qualifications = qualifications,
        specializations = specializations,
        experienceYears = experienceYears,
        serviceRadiusKm = serviceRadiusKm,
        city = city,
        state = state,
        latitude = latitude,
        longitude = longitude,
        certificates = certificates,
        aadhaarUploaded = aadhaarUploaded,
        resetVerificationToPending = resetVerificationToPending,
    )

    @Test fun `userId and scalar numeric fields pass through verbatim`() {
        val dto = build(
            userId = "u-42",
            experienceYears = 7,
            serviceRadiusKm = 60,
            latitude = 17.385,
            longitude = 78.486,
        )
        assertEquals("u-42", dto.userId)
        assertEquals(7, dto.experienceYears)
        assertEquals(60, dto.serviceRadiusKm)
        assertEquals(17.385, dto.latitude!!, 0.0)
        assertEquals(78.486, dto.longitude!!, 0.0)
    }

    @Test fun `blank Aadhaar PAN city state collapse to null`() {
        val dto = build(
            aadhaarNumber = "   ",
            panNumber = "",
            city = "  ",
            state = "",
        )
        assertNull(dto.aadhaarNumber)
        assertNull(dto.panNumber)
        assertNull(dto.city)
        assertNull(dto.state)
    }

    @Test fun `populated Aadhaar PAN city state pass through`() {
        val dto = build(
            aadhaarNumber = "1234 5678 9012",
            panNumber = "ABCDE1234F",
            city = "Hyderabad",
            state = "Telangana",
        )
        assertEquals("1234 5678 9012", dto.aadhaarNumber)
        assertEquals("ABCDE1234F", dto.panNumber)
        assertEquals("Hyderabad", dto.city)
        assertEquals("Telangana", dto.state)
    }

    @Test fun `empty qualifications list collapses to null`() {
        // Why null and not []: Postgrest writes `[]` literally, which on the
        // next read parses to an empty list and shadows the server-side
        // default. The convention is "send null to leave the column alone".
        val dto = build(qualifications = emptyList())
        assertNull(dto.qualifications)
    }

    @Test fun `non-empty qualifications list passes through`() {
        val dto = build(qualifications = listOf("BTech", "MTech"))
        assertEquals(listOf("BTech", "MTech"), dto.qualifications)
    }

    @Test fun `empty specializations list collapses to null`() {
        val dto = build(specializations = emptyList())
        assertNull(dto.specializations)
    }

    @Test fun `specializations are mapped through storageKey before serializing`() {
        val dto = build(
            specializations = listOf(
                RepairEquipmentCategory.ImagingRadiology,
                RepairEquipmentCategory.Dental,
            ),
        )
        assertEquals(listOf("imaging_radiology", "dental"), dto.specializations)
    }

    @Test fun `empty certificates list collapses to null`() {
        val dto = build(certificates = emptyList())
        assertNull(dto.certificates)
    }

    @Test fun `non-empty certificates list passes through unchanged`() {
        val cert = EngineerCertificate(
            type = EngineerCertificate.TYPE_AADHAAR,
            path = "aadhaar/x.jpg",
            uploadedAt = "2026-05-01T09:00:00Z",
        )
        val dto = build(certificates = listOf(cert))
        assertEquals(listOf(cert), dto.certificates)
    }

    @Test fun `aadhaarUploaded false leaves the verified flag null on the wire`() {
        // The one-way write: we never send aadhaar_verified=false from the
        // client, because the only "lose verification" path is server-side
        // admin review. Sending false would clobber a verified engineer.
        val dto = build(aadhaarUploaded = false)
        assertNull(dto.aadhaarVerified)
    }

    @Test fun `aadhaarUploaded true sets verified flag to true`() {
        val dto = build(aadhaarUploaded = true)
        assertEquals(true, dto.aadhaarVerified)
    }

    @Test fun `resetVerificationToPending false leaves verificationStatus null`() {
        // Same protection as above: the column is omitted from a normal
        // KYC edit so we don't downgrade a Verified row back to Pending
        // on a casual profile tweak.
        val dto = build(resetVerificationToPending = false)
        assertNull(dto.verificationStatus)
    }

    @Test fun `resetVerificationToPending true writes pending storage key`() {
        // Triggered only by the re-submit-after-rejection flow.
        val dto = build(resetVerificationToPending = true)
        assertEquals(VerificationStatus.Pending.storageKey, dto.verificationStatus)
        assertEquals("pending", dto.verificationStatus)
    }

    @Test fun `null latitude longitude pass through as null`() {
        val dto = build(latitude = null, longitude = null)
        assertNull(dto.latitude)
        assertNull(dto.longitude)
    }

    @Test fun `zero latitude and longitude pass through unchanged`() {
        // (0, 0) is a valid coordinate in the Atlantic and must not be
        // silently nulled — the upsert should write it.
        val dto = build(latitude = 0.0, longitude = 0.0)
        assertTrue(dto.latitude == 0.0)
        assertTrue(dto.longitude == 0.0)
    }
}
