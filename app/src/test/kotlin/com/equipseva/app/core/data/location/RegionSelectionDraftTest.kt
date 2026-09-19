package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pins local draft consistency, not the currency or official validity of the bundled catalog. */
class RegionSelectionDraftTest {
    @Test fun `new draft has no region and is incomplete`() {
        val draft = RegionSelectionDraft.empty()

        assertNull(draft.state)
        assertNull(draft.district)
        assertFalse(draft.isComplete)
    }

    @Test fun `selecting a listed state requires a district afterwards`() {
        val draft = RegionSelectionDraft.empty().selectState("Telangana")

        assertEquals("Telangana", draft.state)
        assertNull(draft.district)
        assertFalse(draft.isComplete)
    }

    @Test fun `valid state and its district complete the draft`() {
        val draft = RegionSelectionDraft.empty()
            .selectState("Telangana")
            .selectDistrict("Hyderabad")

        assertEquals("Telangana", draft.state)
        assertEquals("Hyderabad", draft.district)
        assertTrue(draft.isComplete)
    }

    @Test fun `district cannot be selected without its parent state`() {
        val draft = RegionSelectionDraft.empty().selectDistrict("Hyderabad")

        assertNull(draft.state)
        assertNull(draft.district)
        assertFalse(draft.isComplete)
    }

    @Test fun `district from another state clears an earlier valid district`() {
        val draft = RegionSelectionDraft.restore("Telangana", "Hyderabad")
            .selectDistrict("Mysuru")

        assertEquals("Telangana", draft.state)
        assertNull(draft.district)
        assertFalse(draft.isComplete)
    }

    @Test fun `changing state clears district even when the name exists under both parents`() {
        // Bilaspur appears under both states in the existing bundled catalog.
        assertTrue(IndiaLocations.districtsFor("Chhattisgarh").contains("Bilaspur"))
        assertTrue(IndiaLocations.districtsFor("Himachal Pradesh").contains("Bilaspur"))
        val previous = RegionSelectionDraft.restore("Chhattisgarh", "Bilaspur")
        val changed = previous.selectState("Himachal Pradesh")

        assertEquals("Himachal Pradesh", changed.state)
        assertNull(changed.district)
        assertFalse(changed.isComplete)
        assertEquals("Bilaspur", changed.selectDistrict("Bilaspur").district)
        assertTrue(changed.selectDistrict("Bilaspur").isComplete)
    }

    @Test fun `selecting the same exact state preserves its district`() {
        val draft = RegionSelectionDraft.restore("Telangana", "Hyderabad")
            .selectState("Telangana")

        assertEquals("Telangana", draft.state)
        assertEquals("Hyderabad", draft.district)
        assertTrue(draft.isComplete)
    }

    @Test fun `invalid state selections clear the entire previous region`() {
        val complete = RegionSelectionDraft.restore("Telangana", "Hyderabad")
        listOf(null, "", " ", "Atlantis").forEach { state ->
            val draft = complete.selectState(state)
            assertNull(draft.state)
            assertNull(draft.district)
            assertFalse(draft.isComplete)
        }
    }

    @Test fun `state selection uses exact catalog membership without substring or normalization`() {
        val complete = RegionSelectionDraft.restore("Telangana", "Hyderabad")
        listOf(
            "telangana", " Telangana", "Telangana ", "Telangana\n",
            "National Capital Territory of Delhi", "outside Telangana", "Telangana\u200B",
        ).forEach { state ->
            val draft = complete.selectState(state)
            assertNull("invalid state must remain unselected", draft.state)
            assertNull(draft.district)
            assertFalse(draft.isComplete)
        }
    }

    @Test fun `invalid district selections retain the state but remove previous district`() {
        val complete = RegionSelectionDraft.restore("Telangana", "Hyderabad")
        listOf(null, "", " ", "Unknown district", "hyderabad", " Hyderabad", "Hyderabad ", "Hyderabad\n")
            .forEach { district ->
                val draft = complete.selectDistrict(district)
                assertEquals("Telangana", draft.state)
                assertNull(draft.district)
                assertFalse(draft.isComplete)
            }
    }

    @Test fun `restoring a valid pair preserves both selections`() {
        val draft = RegionSelectionDraft.restore("Telangana", "Hyderabad")

        assertEquals("Telangana", draft.state)
        assertEquals("Hyderabad", draft.district)
        assertTrue(draft.isComplete)
    }

    @Test fun `restoring an incompatible pair retains only its known state`() {
        val draft = RegionSelectionDraft.restore("Telangana", "Mysuru")

        assertEquals("Telangana", draft.state)
        assertNull(draft.district)
        assertFalse(draft.isComplete)
    }

    @Test fun `restoring unknown or malformed state cannot inherit a real district`() {
        listOf(null, "", "Atlantis", "telangana", "Telangana ").forEach { state ->
            val draft = RegionSelectionDraft.restore(state, "Hyderabad")
            assertNull(draft.state)
            assertNull(draft.district)
            assertFalse(draft.isComplete)
        }
    }

    @Test fun `restoring a known state without an exact district is incomplete`() {
        listOf(null, "", "Unknown district", "hyderabad", "Hyderabad ").forEach { district ->
            val draft = RegionSelectionDraft.restore("Telangana", district)
            assertEquals("Telangana", draft.state)
            assertNull(draft.district)
            assertFalse(draft.isComplete)
        }
    }

    @Test fun `selection transitions do not mutate a previously saved draft`() {
        val empty = RegionSelectionDraft.empty()
        val parentOnly = empty.selectState("Telangana")
        val complete = parentOnly.selectDistrict("Hyderabad")
        val changed = complete.selectState("Karnataka")

        assertNull(empty.state)
        assertNull(parentOnly.district)
        assertEquals("Telangana", complete.state)
        assertEquals("Hyderabad", complete.district)
        assertTrue(complete.isComplete)
        assertEquals("Karnataka", changed.state)
        assertNull(changed.district)
    }

    @Test fun `every bundled district can form a draft only with its listed parent`() {
        // Characterize compatibility with the existing names; this does not certify official data.
        IndiaLocations.STATES.forEach { state ->
            IndiaLocations.districtsFor(state).forEach { district ->
                val draft = RegionSelectionDraft.restore(state, district)
                assertEquals(state, draft.state)
                assertEquals(district, draft.district)
                assertTrue("catalog pair should be locally selectable: $state / $district", draft.isComplete)
            }
        }
    }
}
