package com.equipseva.app.core.storage

import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test

class UploadValidatorTest {

    @Test fun `unknown bucket rejected`() {
        val err = UploadValidator.validate("junk", "image/jpeg", 1024).exceptionOrNull()
        assertTrue(err is UploadError.UnknownBucket)
    }

    @Test fun `repair-photos accepts jpeg png webp`() {
        listOf("image/jpeg", "image/png", "image/webp").forEach { mime ->
            val r = UploadValidator.validate(StorageRepository.Buckets.REPAIR_PHOTOS, mime, 1024)
            assertTrue("$mime should be allowed", r.isSuccess)
        }
    }

    @Test fun `repair-photos rejects pdf`() {
        val r = UploadValidator.validate(
            StorageRepository.Buckets.REPAIR_PHOTOS, "application/pdf", 1024,
        )
        assertTrue(r.exceptionOrNull() is UploadError.MimeNotAllowed)
    }

    @Test fun `invoices accepts pdf only`() {
        assertTrue(UploadValidator.validate(
            StorageRepository.Buckets.INVOICES, "application/pdf", 1024,
        ).isSuccess)
        assertTrue(UploadValidator.validate(
            StorageRepository.Buckets.INVOICES, "image/jpeg", 1024,
        ).exceptionOrNull() is UploadError.MimeNotAllowed)
    }

    @Test fun `kyc accepts jpeg png webp pdf`() {
        listOf("image/jpeg", "image/png", "image/webp", "application/pdf").forEach { mime ->
            assertTrue(UploadValidator.validate(
                StorageRepository.Buckets.KYC_DOCS, mime, 1024,
            ).isSuccess)
        }
    }

    @Test fun `size over max rejected`() {
        val err = UploadValidator.validate(
            StorageRepository.Buckets.REPAIR_PHOTOS, "image/jpeg", 11L * 1024 * 1024,
        ).exceptionOrNull()
        assertTrue(err is UploadError.TooLarge)
    }

    @Test fun `zero size rejected`() {
        val err = UploadValidator.validate(
            StorageRepository.Buckets.REPAIR_PHOTOS, "image/jpeg", 0,
        ).exceptionOrNull()
        assertTrue(err is UploadError.TooLarge)
    }

    @Test fun `missing content-type rejected`() {
        val err = UploadValidator.validate(
            StorageRepository.Buckets.REPAIR_PHOTOS, null, 1024,
        ).exceptionOrNull()
        assertTrue(err is UploadError.MimeNotAllowed)
    }

    @Test fun `content-type with charset parameter is normalized`() {
        val r = UploadValidator.validate(
            StorageRepository.Buckets.CATALOG_IMAGES, "image/jpeg; charset=binary", 1024,
        )
        assertTrue(r.isSuccess)
    }

    @Test fun `case-insensitive mime matching`() {
        val r = UploadValidator.validate(
            StorageRepository.Buckets.INVOICES, "APPLICATION/PDF", 1024,
        )
        assertTrue(r.isSuccess)
    }

    @Test fun `isImage helper recognises supported types only`() {
        assertTrue(UploadValidator.isImage("image/jpeg"))
        assertTrue(UploadValidator.isImage("image/png"))
        assertTrue(UploadValidator.isImage("image/webp"))
        assertEquals(false, UploadValidator.isImage("application/pdf"))
        assertEquals(false, UploadValidator.isImage(null))
    }
}
