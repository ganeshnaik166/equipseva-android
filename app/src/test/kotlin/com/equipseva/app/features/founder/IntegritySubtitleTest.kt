package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class IntegritySubtitleTest {

    @Test fun `named filter shows name dot N events`() {
        assertEquals(
            "Asha Rao · 5 events",
            integritySubtitle(filterUserName = "Asha Rao", filterUserId = "uid-1", rowCount = 5),
        )
    }

    @Test fun `id-only filter shows Filtered dot N events`() {
        // Name didn't resolve but filter is active.
        assertEquals(
            "Filtered · 5 events",
            integritySubtitle(filterUserName = null, filterUserId = "uid-1", rowCount = 5),
        )
    }

    @Test fun `unfiltered with rows shows N events`() {
        assertEquals(
            "10 events",
            integritySubtitle(filterUserName = null, filterUserId = null, rowCount = 10),
        )
    }

    @Test fun `empty unfiltered returns null (clean top bar)`() {
        assertNull(
            integritySubtitle(filterUserName = null, filterUserId = null, rowCount = 0),
        )
    }

    @Test fun `filterUserName precedence over filterUserId`() {
        // Critical pin — name precedence over id when both present.
        // A refactor that flipped order would show "Filtered" even
        // when we have a name to display.
        assertEquals(
            "Asha Rao · 3 events",
            integritySubtitle(filterUserName = "Asha Rao", filterUserId = "uid-1", rowCount = 3),
        )
    }

    @Test fun `blank filterUserName falls through to id-only branch`() {
        // Pin isNullOrBlank gate — blank name is treated as missing.
        assertEquals(
            "Filtered · 2 events",
            integritySubtitle(filterUserName = "   ", filterUserId = "uid-1", rowCount = 2),
        )
    }

    @Test fun `id-only filter shows even on empty rows`() {
        // Filter precedence over rows-empty — we want the filtered
        // state surfaced even when results came back empty.
        assertEquals(
            "Filtered · 0 events",
            integritySubtitle(filterUserName = null, filterUserId = "uid-1", rowCount = 0),
        )
    }

    @Test fun `named filter shows even on empty rows`() {
        assertEquals(
            "Asha Rao · 0 events",
            integritySubtitle(filterUserName = "Asha Rao", filterUserId = "uid-1", rowCount = 0),
        )
    }

    @Test fun `events noun preserved verbatim not flags or attestations`() {
        // Pin "events" — cross-surface vocabulary anchor. The integrity
        // queue tracks events (kind=launch, request_signed, etc.) —
        // distinct from "flags" (which is the cash_flags queue) and
        // "attestations" (the underlying Play Integrity primitive).
        val out = integritySubtitle(null, null, 5)
        assertEquals("5 events", out)
    }
}
