package com.equipseva.app.features.profile

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the account-type section's title + subtitle copy. Critical
 * region: null role (profile mid-fetch) MUST show "Loading…" — a
 * previous regression collapsed null + non-engineer cases into the
 * same `else` branch and surfaced "Hospital admin" as a default,
 * misleading new users about which account they had.
 *
 * Engineer / Hospital get hand-written first-person subtitles
 * because their flows are diametrically opposite (bidder vs booker).
 * Other roles fall back to the enum's `description`.
 */
class AccountTypeSectionCopyTest {

    @Test fun `null role shows neutral Loading title and empty subtitle`() {
        val (title, subtitle) = accountTypeSectionCopy(null)
        // Pin so the mid-fetch state doesn't surface "Hospital admin"
        // again.
        assertEquals("Loading…", title)
        assertEquals("", subtitle)
    }

    @Test fun `null role title uses ellipsis character (not three dots)`() {
        // U+2026 HORIZONTAL ELLIPSIS, not "..." ASCII. Pin so a
        // refactor that ASCII-normalises doesn't slip past review.
        val (title, _) = accountTypeSectionCopy(null)
        assertEquals(true, title.contains('…'))
        assertEquals(false, title.contains("..."))
    }

    @Test fun `Engineer role uses first-person bidder copy`() {
        val (title, subtitle) = accountTypeSectionCopy(UserRole.ENGINEER)
        assertEquals(UserRole.ENGINEER.displayName, title)
        assertEquals("You bid on and complete repair jobs", subtitle)
    }

    @Test fun `Hospital role uses first-person booker copy`() {
        val (title, subtitle) = accountTypeSectionCopy(UserRole.HOSPITAL)
        assertEquals(UserRole.HOSPITAL.displayName, title)
        assertEquals("You book engineers for repairs", subtitle)
    }

    @Test fun `Supplier role falls back to enum description`() {
        // Other roles share the description text in the role-editor;
        // pin so the two surfaces stay in sync.
        val (title, subtitle) = accountTypeSectionCopy(UserRole.SUPPLIER)
        assertEquals(UserRole.SUPPLIER.displayName, title)
        assertEquals(UserRole.SUPPLIER.description, subtitle)
    }

    @Test fun `Manufacturer role falls back to enum description`() {
        val (_, subtitle) = accountTypeSectionCopy(UserRole.MANUFACTURER)
        assertEquals(UserRole.MANUFACTURER.description, subtitle)
    }

    @Test fun `Logistics role falls back to enum description`() {
        val (_, subtitle) = accountTypeSectionCopy(UserRole.LOGISTICS)
        assertEquals(UserRole.LOGISTICS.description, subtitle)
    }

    @Test fun `title always matches UserRole displayName (no diverging copy)`() {
        // Critical: the role-editor sheet's title and this section's
        // title must agree. Pin so a future refactor that hardcoded
        // copy here doesn't drift from UserRole.displayName.
        UserRole.entries.forEach { role ->
            val (title, _) = accountTypeSectionCopy(role)
            assertEquals(
                "title for $role should match displayName",
                role.displayName,
                title,
            )
        }
    }
}
