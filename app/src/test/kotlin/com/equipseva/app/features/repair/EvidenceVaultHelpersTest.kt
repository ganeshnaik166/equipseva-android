package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1408 evidence-vault helpers. */
class EvidenceVaultHelpersTest {

    @Test fun `known evidence kinds map to labels`() {
        assertEquals("Service report (PDF)", evidenceKindLabel("dsr_pdf"))
        assertEquals("Photo — before", evidenceKindLabel("photo_before"))
        assertEquals("Completion OTP", evidenceKindLabel("job_completion_otp"))
        assertEquals("Engineer signature", evidenceKindLabel("signature_engineer"))
    }

    @Test fun `unknown evidence kind de-snakes`() {
        assertEquals("Some new kind", evidenceKindLabel("some_new_kind"))
    }

    @Test fun `producer label - unknown or null is blank`() {
        assertEquals("By engineer", producerKindLabel("engineer"))
        assertEquals("By EquipSeva", producerKindLabel("system"))
        assertEquals("By EquipSeva", producerKindLabel("founder"))
        assertEquals("", producerKindLabel(null))
        assertEquals("", producerKindLabel("robot"))
    }

    @Test fun `byte sizes format 1024-based`() {
        assertEquals("820 B", formatBytes(820))
        assertEquals("1 KB", formatBytes(1024))
        assertEquals("1.5 KB", formatBytes(1536))
        assertEquals("1 MB", formatBytes(1024L * 1024))
    }

    @Test fun `short hash truncates long, keeps short`() {
        assertEquals("abcdef0123…", shortHash("abcdef0123456789"))
        assertEquals("short", shortHash("short"))
    }
}
