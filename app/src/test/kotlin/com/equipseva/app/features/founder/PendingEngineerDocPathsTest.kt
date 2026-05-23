package com.equipseva.app.features.founder

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the tolerant JSONB → List<DocRef> parser on
 * [FounderRepository.PendingEngineer]. The certificates column has
 * been written in two shapes across the lifetime of the schema:
 *
 *   * Legacy (pre-PR #225): a flat list of object paths as strings.
 *   * Current: a list of `{type, path}` objects.
 *
 * The parser tolerates both so KYC rows that pre-date the migration
 * still surface on the founder review screen. A regression that
 * dropped the legacy branch would leave older engineers stuck in the
 * queue with no docs visible.
 *
 * Also pins the [PendingEngineer.DocRef.displayLabel] mapping (Aadhaar /
 * Certificate / fallback title-case).
 */
class PendingEngineerDocPathsTest {

    private fun pending(certs: kotlinx.serialization.json.JsonElement?) =
        FounderRepository.PendingEngineer(
            userId = "u1",
            fullName = "Ravi Kumar",
            verificationStatus = "pending",
            certificates = certs,
        )

    // ---- shape: current (objects with type + path) ----

    @Test fun `current shape - object list maps each entry to a DocRef`() {
        val arr = JsonArray(listOf(
            JsonObject(mapOf(
                "type" to JsonPrimitive("aadhaar"),
                "path" to JsonPrimitive("k/aadhaar.jpg"),
            )),
            JsonObject(mapOf(
                "type" to JsonPrimitive("cert"),
                "path" to JsonPrimitive("k/cert-a.jpg"),
            )),
        ))
        val docs = pending(arr).docPaths()
        assertEquals(2, docs.size)
        assertEquals("aadhaar", docs[0].type)
        assertEquals("k/aadhaar.jpg", docs[0].path)
        assertEquals("cert", docs[1].type)
        assertEquals("k/cert-a.jpg", docs[1].path)
    }

    @Test fun `object entries with blank path are dropped`() {
        val arr = JsonArray(listOf(
            JsonObject(mapOf("type" to JsonPrimitive("aadhaar"), "path" to JsonPrimitive(""))),
            JsonObject(mapOf("type" to JsonPrimitive("aadhaar"), "path" to JsonPrimitive("   "))),
            JsonObject(mapOf("type" to JsonPrimitive("cert"), "path" to JsonPrimitive("k/x.jpg"))),
        ))
        val docs = pending(arr).docPaths()
        assertEquals(1, docs.size)
        assertEquals("k/x.jpg", docs[0].path)
    }

    @Test fun `object entries missing type default to 'doc'`() {
        val arr = JsonArray(listOf(
            JsonObject(mapOf("path" to JsonPrimitive("k/unknown.jpg"))),
        ))
        val docs = pending(arr).docPaths()
        assertEquals("doc", docs[0].type)
        assertEquals("k/unknown.jpg", docs[0].path)
    }

    // ---- shape: legacy (flat string list) ----

    @Test fun `legacy shape - flat string list maps each to a doc-typed DocRef`() {
        val arr = JsonArray(listOf(
            JsonPrimitive("k/legacy-a.jpg"),
            JsonPrimitive("k/legacy-b.jpg"),
        ))
        val docs = pending(arr).docPaths()
        assertEquals(2, docs.size)
        docs.forEach { assertEquals("doc", it.type) }
        assertEquals(listOf("k/legacy-a.jpg", "k/legacy-b.jpg"), docs.map { it.path })
    }

    @Test fun `legacy shape - blank primitives are dropped`() {
        val arr = JsonArray(listOf(
            JsonPrimitive("k/ok.jpg"),
            JsonPrimitive(""),
            JsonPrimitive("   "),
        ))
        val docs = pending(arr).docPaths()
        assertEquals(1, docs.size)
        assertEquals("k/ok.jpg", docs[0].path)
    }

    // ---- edge cases ----

    @Test fun `null certificates yields empty list`() {
        assertTrue(pending(null).docPaths().isEmpty())
    }

    @Test fun `non-array certificates (object or primitive) yields empty list`() {
        // Defensive — the column is jsonb so anything could land in
        // a corrupted row. Don't crash the founder review queue.
        assertTrue(
            pending(JsonObject(mapOf("x" to JsonPrimitive("y")))).docPaths().isEmpty(),
        )
        assertTrue(pending(JsonPrimitive("garbage")).docPaths().isEmpty())
    }

    @Test fun `empty array yields empty list`() {
        assertTrue(pending(JsonArray(emptyList())).docPaths().isEmpty())
    }

    @Test fun `mixed legacy and current entries are both extracted`() {
        // Real rows shouldn't carry both shapes, but a partial
        // migration might — the parser must extract every path
        // regardless of which shape each entry uses.
        val arr = JsonArray(listOf(
            JsonObject(mapOf(
                "type" to JsonPrimitive("aadhaar"),
                "path" to JsonPrimitive("k/aadhaar.jpg"),
            )),
            JsonPrimitive("k/legacy.jpg"),
        ))
        val docs = pending(arr).docPaths()
        assertEquals(2, docs.size)
        assertEquals("aadhaar", docs[0].type)
        assertEquals("doc", docs[1].type)
    }

    // ---- DocRef.displayLabel ----

    @Test fun `displayLabel maps aadhaar to Aadhaar`() {
        assertEquals(
            "Aadhaar",
            FounderRepository.PendingEngineer.DocRef("aadhaar", "k/x").displayLabel,
        )
    }

    @Test fun `displayLabel maps cert to Certificate`() {
        assertEquals(
            "Certificate",
            FounderRepository.PendingEngineer.DocRef("cert", "k/x").displayLabel,
        )
    }

    @Test fun `displayLabel falls back to first-letter title case`() {
        assertEquals(
            "Pan",
            FounderRepository.PendingEngineer.DocRef("pan", "k/x").displayLabel,
        )
        assertEquals(
            "Doc",
            FounderRepository.PendingEngineer.DocRef("doc", "k/x").displayLabel,
        )
    }

    @Test fun `displayLabel is case-insensitive on the type lookup`() {
        // The mapping lower-cases before the when() — pin so an
        // uppercase storage key still maps to the canonical label.
        assertEquals(
            "Aadhaar",
            FounderRepository.PendingEngineer.DocRef("AADHAAR", "k/x").displayLabel,
        )
    }
}
