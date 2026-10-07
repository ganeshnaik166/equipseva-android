package com.equipseva.app.core.data.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RegionSelectionDraftTest {
    private val c = SyntheticRegions.catalog

    @Test
    fun `an empty draft is incomplete and needs no confirmation`() {
        val d = RegionSelectionDraft.empty(c)
        assertFalse(d.isComplete)
        assertFalse(d.needsConfirmation)
        assertNull(d.state)
    }

    @Test
    fun `a State or UT then one of its districts completes the draft`() {
        val d = RegionSelectionDraft.empty(c).selectState("901").selectDistrict("90102")
        assertTrue(d.isComplete)
        assertEquals("Alpha State", d.state!!.name)
        assertEquals("Riverton", d.district!!.name)
    }

    @Test
    fun `changing the State or UT clears the district, even for a shared district name`() {
        val alpha = RegionSelectionDraft.empty(c).selectState("901").selectDistrict("90101")
        val beta = alpha.selectState("902")
        assertEquals("902", beta.stateCode)
        assertNull(beta.districtCode)
        assertFalse(beta.isComplete)
        // Re-selecting the same State/UT keeps the district.
        assertEquals("90101", alpha.selectState("901").districtCode)
    }

    @Test
    fun `a district is refused without its own parent`() {
        assertNull(RegionSelectionDraft.empty(c).selectDistrict("90101").districtCode)
        assertNull(RegionSelectionDraft.empty(c).selectState("902").selectDistrict("90101").districtCode)
    }

    @Test
    fun `unknown and retired codes never count as complete`() {
        assertFalse(RegionSelectionDraft.empty(c).selectState("999").isComplete)
        assertNull(RegionSelectionDraft.empty(c).selectState("903").stateCode)
        assertNull(RegionSelectionDraft.empty(c).selectState("901").selectDistrict("90103").districtCode)
        assertNull(RegionSelectionDraft.empty(c).selectState("901").selectDistrict("99999").districtCode)
    }

    @Test
    fun `restore validates exactly like a fresh selection`() {
        assertTrue(RegionSelectionDraft.restore(c, "901", "90104").isComplete)
        val wrongPair = RegionSelectionDraft.restore(c, "901", "90201")
        assertEquals("901", wrongPair.stateCode)
        assertNull(wrongPair.districtCode)
        val retired = RegionSelectionDraft.restore(c, "901", "90103")
        assertFalse(retired.isComplete)
        assertNull(RegionSelectionDraft.restore(c, "903", "90301").stateCode)
    }

    @Test
    fun `exact legacy text becomes codes`() {
        val d = RegionSelectionDraft.fromLegacy(c, "  alpha   STATE ", "Old Riverton")
        assertTrue(d.isComplete)
        assertEquals("90102", d.districtCode)
        assertFalse(d.needsConfirmation)
    }

    @Test
    fun `unresolved legacy text is kept visible as needing confirmation, never erased or guessed`() {
        val abbreviated = RegionSelectionDraft.fromLegacy(c, "Alpha State", "Northfield Dist.")
        assertEquals("901", abbreviated.stateCode)
        assertNull(abbreviated.districtCode)
        assertTrue(abbreviated.needsConfirmation)
        assertEquals("Northfield Dist.", abbreviated.legacyDistrictLabel)

        val ambiguous = RegionSelectionDraft.fromLegacy(c, "Alpha State", "Lakeside")
        assertNull(ambiguous.districtCode)
        assertTrue(ambiguous.needsConfirmation)

        val unknownState = RegionSelectionDraft.fromLegacy(c, "Unknown State", "Northfield")
        assertNull(unknownState.stateCode)
        assertTrue(unknownState.needsConfirmation)
        assertEquals("Unknown State", unknownState.legacyStateLabel)

        // Confirming codes clears the prompt; the old text stays available for display.
        val confirmed = abbreviated.selectDistrict("90101")
        assertTrue(confirmed.isComplete)
        assertFalse(confirmed.needsConfirmation)
        assertEquals("Northfield Dist.", confirmed.legacyDistrictLabel)
    }

    @Test
    fun `text the server would not resolve never completes on the device`() {
        val nbsp = Char(0xA0)
        val trailing = RegionSelectionDraft.fromLegacy(c, "Alpha State", "Northfield$nbsp")
        assertNull(trailing.districtCode)
        assertTrue(trailing.needsConfirmation)
        // A label made only of a non-breaking space is text to the server (state_unknown), not blank.
        assertTrue(RegionSelectionDraft.fromLegacy(c, "$nbsp", null).needsConfirmation)
    }

    @Test
    fun `no legacy text means nothing to confirm`() {
        val d = RegionSelectionDraft.fromLegacy(c, null, "  ")
        assertFalse(d.isComplete)
        assertFalse(d.needsConfirmation)
    }
}
