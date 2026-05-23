package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EscrowEventRowHelpersTest {

    // ---- escrowEventKindLabel ----------------------------------------

    @Test fun `snake case event kind gets spaces and first capital`() {
        assertEquals(
            "Dispute resolved",
            escrowEventKindLabel("dispute_resolved"),
        )
    }

    @Test fun `single-word event kind still gets first-letter capitalised`() {
        assertEquals("Created", escrowEventKindLabel("created"))
        assertEquals("Paid", escrowEventKindLabel("paid"))
    }

    @Test fun `multi-underscore event kind replaces all underscores`() {
        assertEquals(
            "Release scheduled with delay",
            escrowEventKindLabel("release_scheduled_with_delay"),
        )
    }

    // ---- escrowEventActorLine ----------------------------------------

    @Test fun `non-blank actor name reads Actor name`() {
        assertEquals(
            "Actor: Founder Admin",
            escrowEventActorLine("Founder Admin", "uid-123"),
        )
    }

    @Test fun `parens-system actor name with no user id surfaces system label`() {
        // Critical pin — "(system)" is a server placeholder that
        // mustn't leak to the UI. The fallback "Actor: system" reads
        // cleaner.
        assertEquals(
            "Actor: system",
            escrowEventActorLine("(system)", null),
        )
    }

    @Test fun `parens-system actor name WITH user id returns null (don't mislead)`() {
        // A non-null userId means there IS a user; the join just
        // didn't resolve. Showing "Actor: system" would be wrong;
        // showing "Actor: (system)" would leak the placeholder.
        // Return null → don't render the line.
        assertNull(escrowEventActorLine("(system)", "uid-real"))
    }

    @Test fun `null actor name with null user id surfaces Actor system`() {
        // Pure system event — no actor recorded, no user id.
        assertEquals(
            "Actor: system",
            escrowEventActorLine(null, null),
        )
    }

    @Test fun `blank actor name with null user id surfaces Actor system`() {
        assertEquals(
            "Actor: system",
            escrowEventActorLine("   ", null),
        )
    }

    @Test fun `null actor name with non-null user id returns null (unresolved join)`() {
        // Pin — don't show "Actor:" with nothing after it.
        assertNull(escrowEventActorLine(null, "uid-real"))
    }

    // ---- escrowEventPayloadDisplay -----------------------------------

    @Test fun `null payload returns null`() {
        assertNull(escrowEventPayloadDisplay(null))
    }

    @Test fun `empty payload returns null`() {
        assertNull(escrowEventPayloadDisplay(""))
    }

    @Test fun `whitespace-only payload returns null`() {
        assertNull(escrowEventPayloadDisplay("   "))
    }

    @Test fun `JSON empty object braces returns null`() {
        // Critical pin — server-side JSONB column surfaces "{}" when
        // there's no extra data on the event; this would be UI noise.
        assertNull(escrowEventPayloadDisplay("{}"))
    }

    @Test fun `non-empty JSON payload passes through verbatim`() {
        assertEquals(
            "{\"reason\":\"hospital_revoked\"}",
            escrowEventPayloadDisplay("{\"reason\":\"hospital_revoked\"}"),
        )
    }

    @Test fun `JSON with one space inside braces is NOT filtered (only literal empty-braces)`() {
        // Pin exact-string match — "{ }" passes through (caller can
        // choose to clean it server-side). Filtering "{ }" would
        // require trimming logic the caller doesn't need.
        assertEquals("{ }", escrowEventPayloadDisplay("{ }"))
    }
}
