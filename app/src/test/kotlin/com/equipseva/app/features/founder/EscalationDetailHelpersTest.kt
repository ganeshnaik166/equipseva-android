package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EscalationDetailHelpersTest {

    // ---- escalationDetailResolvedPillTextAndKind ---------------------

    @Test fun `both null resolvedAt and false locallyResolved → Open Danger`() {
        assertEquals(
            "Open" to PillKind.Danger,
            escalationDetailResolvedPillTextAndKind(resolvedAt = null, locallyResolved = false),
        )
    }

    @Test fun `non-null resolvedAt → Resolved Success`() {
        // Server-confirmed resolution.
        assertEquals(
            "Resolved" to PillKind.Success,
            escalationDetailResolvedPillTextAndKind(
                resolvedAt = "2026-05-23T14:30:00Z",
                locallyResolved = false,
            ),
        )
    }

    @Test fun `local resolved flag alone → Resolved Success (optimistic UI)`() {
        // Critical pin — without this branch, the pill would
        // read Open for ~500ms after the founder tapped resolve,
        // making the action feel like it failed.
        assertEquals(
            "Resolved" to PillKind.Success,
            escalationDetailResolvedPillTextAndKind(resolvedAt = null, locallyResolved = true),
        )
    }

    @Test fun `both true → Resolved Success (server caught up to local flag)`() {
        assertEquals(
            "Resolved" to PillKind.Success,
            escalationDetailResolvedPillTextAndKind(
                resolvedAt = "2026-05-23T14:30:00Z",
                locallyResolved = true,
            ),
        )
    }

    @Test fun `empty resolvedAt string counts as non-null → Resolved`() {
        // Pin exact null gate — a refactor to isNullOrBlank would
        // surface Open here. Whether that's right depends on data
        // semantics; current behaviour says any non-null timestamp
        // (even empty) means the server marked it resolved.
        assertEquals(
            "Resolved" to PillKind.Success,
            escalationDetailResolvedPillTextAndKind(resolvedAt = "", locallyResolved = false),
        )
    }

    @Test fun `Open uses Danger NOT Warn`() {
        // Pin red, not amber. Open escalations are load-bearing
        // queue items — Danger signals priority.
        val (_, kind) = escalationDetailResolvedPillTextAndKind(null, false)
        assertEquals(PillKind.Danger, kind)
    }

    // ---- escalationDetailRotationHeader ------------------------------

    @Test fun `rotation header puts count in parens`() {
        assertEquals(
            "Engineer rotation (3)",
            escalationDetailRotationHeader(3),
        )
    }

    @Test fun `rotation header on empty list reads parens-zero`() {
        // Defensive — the caller swaps to "No engineers in rotation"
        // when the list is empty, but pin the helper stays total.
        assertEquals(
            "Engineer rotation (0)",
            escalationDetailRotationHeader(0),
        )
    }

    @Test fun `Engineer rotation phrasing preserved verbatim`() {
        // Pin literal — a refactor to "Rotation" or "Engineers in
        // rotation" would diverge from the founder's standard
        // list-header signature.
        val out = escalationDetailRotationHeader(5)
        assertTrue(out.startsWith("Engineer rotation "))
    }

    @Test fun `parens-count format preferred over middle-dot or colon`() {
        // Pin format — the founder's standard list-header signature.
        val out = escalationDetailRotationHeader(7)
        assertEquals(false, out.contains(" · "))
        assertEquals(false, out.contains(": "))
        assertTrue(out.endsWith("(7)"))
    }
}
