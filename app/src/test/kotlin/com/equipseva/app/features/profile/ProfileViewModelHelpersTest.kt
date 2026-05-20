package com.equipseva.app.features.profile

import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerCertificate
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the three pure helpers extracted out of ProfileViewModel:
 *  - isEngineerKycSubmitted distinguishes "draft" from "in review" while
 *    the backend still reports a single Pending status. If this gate
 *    drifts, the Profile KYC chip lies to the engineer.
 *  - nextRoleForToggle drives the Engineer ↔ Hospital "Switch" CTA — any
 *    no-op fallback would leave the toggle dead.
 *  - avatarExtensionForMime picks the file suffix we persist into the
 *    `avatars` bucket on photo upload.
 */
class ProfileViewModelHelpersTest {

    private fun cert(type: String, path: String = "p/$type.jpg"): EngineerCertificate =
        EngineerCertificate(type = type, path = path, uploadedAt = "2026-01-01T00:00:00Z")

    private fun engineer(certificates: List<EngineerCertificate>): Engineer = Engineer(
        id = "eng-1",
        userId = "user-1",
        aadhaarNumber = null,
        aadhaarVerified = false,
        qualifications = emptyList(),
        specializations = emptyList(),
        brandsServiced = emptyList(),
        experienceYears = 0,
        serviceRadiusKm = 25,
        city = null,
        state = null,
        verificationStatus = VerificationStatus.Pending,
        backgroundCheckStatus = VerificationStatus.Pending,
        certificates = certificates,
    )

    @Test fun `null engineer is never submitted`() {
        assertFalse(isEngineerKycSubmitted(null))
    }

    @Test fun `all three docs present counts as submitted`() {
        val eng = engineer(
            listOf(
                cert(EngineerCertificate.TYPE_AADHAAR),
                cert(EngineerCertificate.TYPE_PAN),
                cert(EngineerCertificate.TYPE_CERT),
            ),
        )
        assertTrue(isEngineerKycSubmitted(eng))
    }

    @Test fun `missing aadhaar blocks submitted`() {
        val eng = engineer(
            listOf(
                cert(EngineerCertificate.TYPE_PAN),
                cert(EngineerCertificate.TYPE_CERT),
            ),
        )
        assertFalse(isEngineerKycSubmitted(eng))
    }

    @Test fun `missing pan blocks submitted`() {
        val eng = engineer(
            listOf(
                cert(EngineerCertificate.TYPE_AADHAAR),
                cert(EngineerCertificate.TYPE_CERT),
            ),
        )
        assertFalse(isEngineerKycSubmitted(eng))
    }

    @Test fun `missing cert blocks submitted`() {
        // Selfie alone doesn't count as a TYPE_CERT — Aadhaar + PAN
        // without a training cert is still "draft".
        val eng = engineer(
            listOf(
                cert(EngineerCertificate.TYPE_AADHAAR),
                cert(EngineerCertificate.TYPE_PAN),
                cert(EngineerCertificate.TYPE_SELFIE),
            ),
        )
        assertFalse(isEngineerKycSubmitted(eng))
    }

    @Test fun `multiple certs are fine, only one is required`() {
        val eng = engineer(
            listOf(
                cert(EngineerCertificate.TYPE_AADHAAR),
                cert(EngineerCertificate.TYPE_PAN),
                cert(EngineerCertificate.TYPE_CERT, "p/a.jpg"),
                cert(EngineerCertificate.TYPE_CERT, "p/b.jpg"),
            ),
        )
        assertTrue(isEngineerKycSubmitted(eng))
    }

    @Test fun `engineer toggles to hospital`() {
        assertEquals(UserRole.HOSPITAL, nextRoleForToggle(UserRole.ENGINEER))
    }

    @Test fun `hospital toggles to engineer`() {
        assertEquals(UserRole.ENGINEER, nextRoleForToggle(UserRole.HOSPITAL))
    }

    @Test fun `non engineer non hospital roles fall through to hospital`() {
        // Supplier / manufacturer / logistics aren't supposed to land on
        // this CTA in v1, but if they do the toggle still has a defined
        // landing role so the button is never a no-op.
        assertEquals(UserRole.HOSPITAL, nextRoleForToggle(UserRole.SUPPLIER))
        assertEquals(UserRole.HOSPITAL, nextRoleForToggle(UserRole.MANUFACTURER))
        assertEquals(UserRole.HOSPITAL, nextRoleForToggle(UserRole.LOGISTICS))
    }

    @Test fun `every UserRole maps to a defined toggle target`() {
        // Catches a future role added to the enum that silently lands
        // back on the same role (toggle becomes a no-op).
        UserRole.entries.forEach { role ->
            val next = nextRoleForToggle(role)
            assertTrue(
                "toggling $role landed on $next, which is the same role",
                next != role,
            )
        }
    }

    @Test fun `png mime maps to png`() {
        assertEquals("png", avatarExtensionForMime("image/png"))
    }

    @Test fun `webp mime maps to webp`() {
        assertEquals("webp", avatarExtensionForMime("image/webp"))
    }

    @Test fun `jpeg and everything else fall through to jpg`() {
        assertEquals("jpg", avatarExtensionForMime("image/jpeg"))
        assertEquals("jpg", avatarExtensionForMime("image/jpg"))
        assertEquals("jpg", avatarExtensionForMime("image/heic"))
        assertEquals("jpg", avatarExtensionForMime(""))
    }

    @Test fun `mime lookup is case insensitive`() {
        // Some ContentResolvers return upper-case MIME types — the
        // lowercase() guard inside the helper keeps the suffix sane.
        assertEquals("png", avatarExtensionForMime("IMAGE/PNG"))
        assertEquals("webp", avatarExtensionForMime("Image/WebP"))
    }
}
