package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the founder category sort-order parse.
 *
 * Critical regression target: `toIntOrNull() ?: 100` silently substituted the
 * default for anything it could not parse. A value past Int range — one extra
 * digit, or a pasted number — was saved as 100, reported success, and moved
 * the category to a position the founder never chose. The field accepted
 * unlimited digits, so this was reachable by typing. The refusal is keyed on
 * the column's range, not on how wide the row renders.
 *
 * Null here means "refuse the save and show an error", which is why blank has
 * to stay distinguishable from invalid: the field starts empty for a new
 * category and empty legitimately means "use the default".
 */
class CategorySortOrderTest {

    @Test fun `plain digits parse`() {
        assertEquals(0, categorySortOrderOrNull("0"))
        assertEquals(7, categorySortOrderOrNull("7"))
        assertEquals(250, categorySortOrderOrNull("250"))
    }

    @Test fun `blank means use the default`() {
        assertEquals(CATEGORY_SORT_ORDER_DEFAULT, categorySortOrderOrNull(""))
        assertEquals(CATEGORY_SORT_ORDER_DEFAULT, categorySortOrderOrNull("   "))
    }

    @Test fun `the documented default is 100`() {
        // Pinned separately: server rows created before the field existed sort
        // at 100, so a change here reshuffles every untouched category.
        assertEquals(100, CATEGORY_SORT_ORDER_DEFAULT)
    }

    @Test fun `the bound is the column's, not a display preference`() {
        // sort_order is a plain int with no CHECK and the upsert takes the
        // whole range. A tighter client rule refused to save a row it had no
        // part in creating: the founder renames a legacy category and is told
        // to retype an ordering they never chose, which reshuffles the list.
        assertEquals(999_999, categorySortOrderOrNull("999999"))
        assertEquals(1_000_000, categorySortOrderOrNull("1000000"))
        assertEquals(Int.MAX_VALUE, categorySortOrderOrNull("2147483647"))
    }

    @Test fun `a value past Int range is refused rather than defaulted`() {
        // The exact shape of the original bug: this used to come back as 100.
        assertNull(categorySortOrderOrNull("99999999999"))
        assertNull(categorySortOrderOrNull("2147483648"))
    }

    @Test fun `non numeric input is refused`() {
        assertNull(categorySortOrderOrNull("abc"))
        assertNull(categorySortOrderOrNull("12a"))
        assertNull(categorySortOrderOrNull("-5"))
    }
}
