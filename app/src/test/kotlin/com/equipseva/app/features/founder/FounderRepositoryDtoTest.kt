package com.equipseva.app.features.founder

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the two member helpers on FounderRepository.PendingEngineer:
 *  - `docPaths()` — pulls storage-key paths out of the certificates
 *    JSONB column, tolerating the legacy shape (objects with type+path)
 *    AND the flat string-list shape used by the new uploader.
 *  - `DocRef.displayLabel` — bucket-name pretty label for the doc tile.
 */
class FounderRepositoryDtoTest {

    private fun engineer(
        certificates: kotlinx.serialization.json.JsonElement? = null,
    ): FounderRepository.PendingEngineer = FounderRepository.PendingEngineer(
        userId = "u-1",
        fullName = "Ravi",
        verificationStatus = "pending",
        certificates = certificates,
    )

    @Test fun `docPaths returns empty list when certificates is null`() {
        // Profiles with no docs uploaded yet — never crash on null JSONB.
        assertTrue(engineer(certificates = null).docPaths().isEmpty())
    }

    @Test fun `docPaths returns empty when certificates is not an array`() {
        // Defensive — the helper only knows how to walk JsonArray. A
        // legacy malformed row stored as a JSON object collapses safely
        // to an empty list rather than throwing.
        val asObject = JsonObject(mapOf("foo" to JsonPrimitive("bar")))
        assertTrue(engineer(certificates = asObject).docPaths().isEmpty())
    }

    @Test fun `docPaths reads the legacy object shape with type and path`() {
        // Shape: [{"type": "aadhaar", "path": "users/u1/aadhaar.jpg"}, …]
        val arr = JsonArray(listOf(
            JsonObject(mapOf(
                "type" to JsonPrimitive("aadhaar"),
                "path" to JsonPrimitive("users/u1/aadhaar.jpg"),
            )),
            JsonObject(mapOf(
                "type" to JsonPrimitive("cert"),
                "path" to JsonPrimitive("users/u1/cert.pdf"),
            )),
        ))
        val docs = engineer(certificates = arr).docPaths()
        assertEquals(2, docs.size)
        assertEquals("aadhaar", docs[0].type)
        assertEquals("users/u1/aadhaar.jpg", docs[0].path)
        assertEquals("cert", docs[1].type)
        assertEquals("users/u1/cert.pdf", docs[1].path)
    }

    @Test fun `docPaths defaults missing type to doc`() {
        // Object without a "type" field — fall back to the generic
        // "doc" label rather than dropping the row.
        val arr = JsonArray(listOf(
            JsonObject(mapOf("path" to JsonPrimitive("users/u1/x.pdf"))),
        ))
        val docs = engineer(certificates = arr).docPaths()
        assertEquals(1, docs.size)
        assertEquals("doc", docs[0].type)
        assertEquals("users/u1/x.pdf", docs[0].path)
    }

    @Test fun `docPaths drops objects missing a path field`() {
        // No path → can't sign a URL → skip entirely.
        val arr = JsonArray(listOf(
            JsonObject(mapOf("type" to JsonPrimitive("cert"))),
        ))
        assertTrue(engineer(certificates = arr).docPaths().isEmpty())
    }

    @Test fun `docPaths drops objects with blank path`() {
        val arr = JsonArray(listOf(
            JsonObject(mapOf(
                "type" to JsonPrimitive("cert"),
                "path" to JsonPrimitive(""),
            )),
        ))
        assertTrue(engineer(certificates = arr).docPaths().isEmpty())
    }

    @Test fun `docPaths reads the flat string-list shape`() {
        // New uploader writes ["users/u1/a.jpg", "users/u1/b.pdf"].
        val arr = JsonArray(listOf(
            JsonPrimitive("users/u1/a.jpg"),
            JsonPrimitive("users/u1/b.pdf"),
        ))
        val docs = engineer(certificates = arr).docPaths()
        assertEquals(2, docs.size)
        assertEquals("doc", docs[0].type)
        assertEquals("users/u1/a.jpg", docs[0].path)
        assertEquals("doc", docs[1].type)
        assertEquals("users/u1/b.pdf", docs[1].path)
    }

    @Test fun `docPaths drops blank primitives in the flat list`() {
        // Defensive — an accidentally-stored empty string shouldn't
        // produce a "open" button with no path behind it.
        val arr = JsonArray(listOf(
            JsonPrimitive(""),
            JsonPrimitive("   "),
            JsonPrimitive("users/u1/keep.jpg"),
        ))
        val docs = engineer(certificates = arr).docPaths()
        assertEquals(1, docs.size)
        assertEquals("users/u1/keep.jpg", docs[0].path)
    }

    @Test fun `docPaths drops null entries inside the array`() {
        // A legacy row with `[null, {...}]` — null branches return null
        // via the else case in the when and get filtered by mapNotNull.
        val arr = JsonArray(listOf(
            JsonNull,
            JsonObject(mapOf(
                "type" to JsonPrimitive("aadhaar"),
                "path" to JsonPrimitive("users/u1/a.jpg"),
            )),
        ))
        val docs = engineer(certificates = arr).docPaths()
        assertEquals(1, docs.size)
        assertEquals("aadhaar", docs[0].type)
    }

    @Test fun `DocRef displayLabel maps aadhaar and cert to title-cased labels`() {
        // Two well-known doc kinds get a human label; matches the chips
        // that appear in the founder review screen doc grid.
        assertEquals(
            "Aadhaar",
            FounderRepository.PendingEngineer.DocRef("aadhaar", "p").displayLabel,
        )
        assertEquals(
            "Certificate",
            FounderRepository.PendingEngineer.DocRef("cert", "p").displayLabel,
        )
    }

    @Test fun `DocRef displayLabel case-folds the input for the known-types switch`() {
        // Upper-case "AADHAAR" still matches the Aadhaar branch — pins
        // the `lowercase()` call so a refactor that drops it is caught.
        assertEquals(
            "Aadhaar",
            FounderRepository.PendingEngineer.DocRef("AADHAAR", "p").displayLabel,
        )
    }

    @Test fun `DocRef displayLabel capitalises the first char of unknown types`() {
        // Unknown kind (e.g. "pan", "selfie") gets a generic
        // capitalised label rather than blank or hidden.
        assertEquals(
            "Pan",
            FounderRepository.PendingEngineer.DocRef("pan", "p").displayLabel,
        )
        assertEquals(
            "Selfie",
            FounderRepository.PendingEngineer.DocRef("selfie", "p").displayLabel,
        )
    }
}
