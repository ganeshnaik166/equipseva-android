package com.equipseva.app.features.profile.forms

import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the JsonObject → text/switch splitter and the empty-form Save guard
 * sitting inside [ProfileFormViewModel]. UserSettingsRepository accepts any
 * JSON, so a regression on the splitter would silently drop fields or stash
 * a "true" string into a text field.
 */
class ProfileFormsHelpersTest {

    /* --------- splitJsonValues --------- */

    @Test fun `splitJsonValues null input returns two empty maps`() {
        val (texts, switches) = splitJsonValues(null)
        assertTrue(texts.isEmpty())
        assertTrue(switches.isEmpty())
    }

    @Test fun `splitJsonValues routes boolean primitives into switches`() {
        val obj = buildJsonObject {
            put("default_payout", true)
            put("auto_quote_repeat", false)
        }
        val (texts, switches) = splitJsonValues(obj)
        assertTrue(texts.isEmpty())
        assertEquals(mapOf("default_payout" to true, "auto_quote_repeat" to false), switches)
    }

    @Test fun `splitJsonValues routes string primitives into texts`() {
        val obj = buildJsonObject {
            put("ifsc", "SBIN0001234")
            put("branch", "Koramangala")
        }
        val (texts, switches) = splitJsonValues(obj)
        assertEquals(mapOf("ifsc" to "SBIN0001234", "branch" to "Koramangala"), texts)
        assertTrue(switches.isEmpty())
    }

    @Test fun `splitJsonValues numeric primitives flow to texts as their content string`() {
        val obj = buildJsonObject {
            put("auto_approve_under", 5000)
            put("default_tax_slab", 18.5)
        }
        val (texts, _) = splitJsonValues(obj)
        assertEquals("5000", texts["auto_approve_under"])
        assertEquals("18.5", texts["default_tax_slab"])
    }

    @Test fun `splitJsonValues null primitive maps to an empty string`() {
        // The repository round-trips JSON null to JsonPrimitive(null), whose
        // contentOrNull is null — handled by .orEmpty() so the field renders
        // as a blank text input, not a literal "null".
        val obj = buildJsonObject { put("legacy_field", JsonPrimitive(null as String?)) }
        val (texts, _) = splitJsonValues(obj)
        assertEquals("", texts["legacy_field"])
    }

    @Test fun `splitJsonValues complex non-primitive values fall through to toString`() {
        // Nested objects stored by a future migration shouldn't crash the
        // form — they just render as their JSON.toString().
        val obj = buildJsonObject {
            put(
                "nested",
                buildJsonObject { put("brand", "Acme") },
            )
        }
        val (texts, switches) = splitJsonValues(obj)
        assertTrue(texts["nested"]!!.startsWith("{"))
        assertTrue(switches.isEmpty())
    }

    @Test fun `splitJsonValues mixed object splits cleanly`() {
        val obj = buildJsonObject {
            put("display_name", "Equipseva Spares")
            put("tagline", "Genuine OEM")
            put("auto_quote_repeat", true)
        }
        val (texts, switches) = splitJsonValues(obj)
        assertEquals(2, texts.size)
        assertEquals(1, switches.size)
        assertEquals("Equipseva Spares", texts["display_name"])
        assertEquals(true, switches["auto_quote_repeat"])
    }

    /* --------- hasFormContent --------- */

    @Test fun `hasFormContent false when both maps are empty`() {
        assertFalse(hasFormContent(emptyMap(), emptyMap()))
    }

    @Test fun `hasFormContent false when all text values are blank`() {
        assertFalse(hasFormContent(mapOf("a" to "", "b" to "   "), emptyMap()))
    }

    @Test fun `hasFormContent true when any text value is non-blank`() {
        assertTrue(hasFormContent(mapOf("a" to "", "b" to "x"), emptyMap()))
    }

    @Test fun `hasFormContent true when the switches map is non-empty even if all toggles are false`() {
        // A switch present in the map means the user touched it at least
        // once; we preserve that intent over treating "everything false"
        // as empty.
        assertTrue(hasFormContent(emptyMap(), mapOf("default_payout" to false)))
    }

    @Test fun `hasFormContent true with both content sources present`() {
        assertTrue(
            hasFormContent(
                mapOf("ifsc" to "SBIN0001234"),
                mapOf("default_payout" to true),
            ),
        )
    }
}
