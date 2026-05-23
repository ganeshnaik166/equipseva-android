package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

class CategoryRowHelpersTest {

    // ---- categoryActiveLabel -----------------------------------------

    @Test fun `active true reads Active`() {
        assertEquals("Active", categoryActiveLabel(true))
    }

    @Test fun `active false reads Disabled not Inactive`() {
        // Critical pin — "Disabled" communicates founder intent
        // (toggled off). "Inactive" would imply dormancy on its own.
        assertEquals("Disabled", categoryActiveLabel(false))
    }

    @Test fun `labels are Title-cased single words`() {
        // Pin format — both branches are single Title-cased words.
        val on = categoryActiveLabel(true)
        val off = categoryActiveLabel(false)
        assertEquals(true, on[0].isUpperCase())
        assertEquals(true, off[0].isUpperCase())
        assertEquals(false, on.contains(" "))
        assertEquals(false, off.contains(" "))
    }

    // ---- categoryScopeOrderLine --------------------------------------

    @Test fun `composes lowercase scope colon value middle-dot order colon value`() {
        assertEquals(
            "scope: both · order: 100",
            categoryScopeOrderLine("both", 100),
        )
    }

    @Test fun `lowercase labels preserved (not Title-cased)`() {
        // Pin lowercase — technical hint labels shouldn't compete
        // visually with the primary displayName.
        val out = categoryScopeOrderLine("both", 100)
        assertEquals(true, out.startsWith("scope: "))
        assertEquals(false, out.startsWith("Scope: "))
    }

    @Test fun `middle dot is U+00B7 not bullet`() {
        val out = categoryScopeOrderLine("x", 1)
        assertEquals(true, out.contains('·'))
        assertEquals(false, out.contains('•'))
    }

    @Test fun `scope value passes through verbatim`() {
        // Pin no transformation — preserve "both" / "buy" / "sell"
        // as-is. A refactor that title-cased would surface "Both".
        assertEquals(
            "scope: BOTH · order: 5",
            categoryScopeOrderLine("BOTH", 5),
        )
    }

    @Test fun `large order value renders without thousands grouping`() {
        // Pin no comma grouping — sort orders are sortable ints, not
        // currency. A refactor to formatRupees would surface "₹1,200"
        // mistakenly.
        assertEquals(
            "scope: both · order: 1200",
            categoryScopeOrderLine("both", 1200),
        )
    }
}
