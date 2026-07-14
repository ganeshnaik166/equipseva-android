package com.equipseva.app.features.mybids

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Pins for the r1394 job-profitability helpers. */
class JobProfitabilityHelpersTest {

    @Test fun `below floor reads danger`() {
        assertEquals("Below your floor" to PillKind.Danger, profitBadgeTextAndKind(true))
    }

    @Test fun `above floor reads success`() {
        assertEquals("Above your floor" to PillKind.Success, profitBadgeTextAndKind(false))
    }

    @Test fun `blank floor input has no error`() {
        assertNull(profitabilityFloorError(""))
        assertNull(profitabilityFloorError("   "))
    }

    @Test fun `in-range floors pass, including the boundaries`() {
        assertNull(profitabilityFloorError("0"))
        assertNull(profitabilityFloorError("1500"))
        assertNull(profitabilityFloorError("50000"))
    }

    @Test fun `non-numeric floor is rejected`() {
        assertEquals("Enter a number.", profitabilityFloorError("abc"))
    }

    @Test fun `negative floor is rejected`() {
        assertEquals("Floor can't be negative.", profitabilityFloorError("-1"))
    }

    @Test fun `floor above the 50k cap is rejected`() {
        assertEquals("Floor can't exceed ₹50,000.", profitabilityFloorError("50001"))
    }
}
