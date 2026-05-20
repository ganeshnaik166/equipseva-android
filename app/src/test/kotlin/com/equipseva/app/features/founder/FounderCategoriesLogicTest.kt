package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the two pure helpers behind the founder Categories editor:
 *  - `founderCategoryImageExt` — MIME → storage-path extension.
 *  - `founderValidateCategoryDraft` — null on success, founder-facing
 *    error string on failure. Mirrors the SQL CHECK on
 *    categories.scope so the founder sees a friendly error before the
 *    request is fired.
 */
class FounderCategoriesLogicTest {

    @Test fun `png and webp map to their own ext`() {
        // Lossless paths kept as-is so Storage doesn't re-encode them.
        assertEquals("png", founderCategoryImageExt("image/png"))
        assertEquals("webp", founderCategoryImageExt("image/webp"))
    }

    @Test fun `jpeg variants and unknown MIMEs all fall through to jpg`() {
        // Any non-png/webp upload settles on jpg — Storage transcodes
        // server-side anyway, so this is just a sensible default path
        // extension.
        assertEquals("jpg", founderCategoryImageExt("image/jpeg"))
        assertEquals("jpg", founderCategoryImageExt("image/jpg"))
        assertEquals("jpg", founderCategoryImageExt("application/octet-stream"))
        assertEquals("jpg", founderCategoryImageExt(""))
    }

    @Test fun `MIME is matched case-insensitively`() {
        // Some Android content providers return uppercase MIMEs;
        // the lowercase() guard means png stays png.
        assertEquals("png", founderCategoryImageExt("IMAGE/PNG"))
        assertEquals("webp", founderCategoryImageExt("Image/WebP"))
    }

    @Test fun `validate returns null when key, name, and known scope`() {
        // Happy path — all three valid scopes accepted.
        assertNull(founderValidateCategoryDraft("ct", "CT Scanner", "spare_part"))
        assertNull(founderValidateCategoryDraft("ct", "CT Scanner", "repair"))
        assertNull(founderValidateCategoryDraft("ct", "CT Scanner", "both"))
    }

    @Test fun `validate rejects blank key with a single error string`() {
        // Key + name share the same error so the founder doesn't get a
        // two-step prompt; the form highlights both fields client-side.
        assertEquals(
            "Key and name are required",
            founderValidateCategoryDraft("", "CT Scanner", "both"),
        )
    }

    @Test fun `validate rejects blank name`() {
        assertEquals(
            "Key and name are required",
            founderValidateCategoryDraft("ct", "", "both"),
        )
    }

    @Test fun `validate rejects whitespace-only key or name`() {
        // The helper uses isBlank() — pin so a refactor to isEmpty()
        // (which would let "   " sneak through) is caught.
        assertEquals(
            "Key and name are required",
            founderValidateCategoryDraft("   ", "CT Scanner", "both"),
        )
        assertEquals(
            "Key and name are required",
            founderValidateCategoryDraft("ct", "   ", "both"),
        )
    }

    @Test fun `validate rejects unknown scope`() {
        // Matches the SQL CHECK on categories.scope. Front-end blocks
        // anything outside the trio so we never hit a constraint
        // violation on the server.
        assertEquals(
            "Scope must be spare_part, repair, or both",
            founderValidateCategoryDraft("ct", "CT Scanner", "something_else"),
        )
        assertEquals(
            "Scope must be spare_part, repair, or both",
            founderValidateCategoryDraft("ct", "CT Scanner", ""),
        )
    }

    @Test fun `validate prefers the key-or-name error over scope error`() {
        // When both checks would fail, we want the more actionable
        // error first — the founder needs the key/name highlight even
        // if the scope also drifted.
        assertEquals(
            "Key and name are required",
            founderValidateCategoryDraft("", "", "not_a_scope"),
        )
    }
}
