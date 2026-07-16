package com.equipseva.app.features.hospital

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1422 chain site-invite helpers. */
class ChainInvitesHelpersTest {

    @Test fun `status pill maps known invite states`() {
        assertEquals("Pending" to PillKind.Warn, chainInviteStatusPill("pending"))
        assertEquals("Accepted" to PillKind.Success, chainInviteStatusPill("accepted"))
        assertEquals("Revoked" to PillKind.Neutral, chainInviteStatusPill("revoked"))
        assertEquals("Expired" to PillKind.Neutral, chainInviteStatusPill("expired"))
    }

    @Test fun `unknown status de-snakes with Neutral tone`() {
        assertEquals("On hold" to PillKind.Neutral, chainInviteStatusPill("on_hold"))
    }

    @Test fun `only pending invites can be revoked`() {
        assertEquals(true, canRevokeInvite("pending"))
        assertEquals(false, canRevokeInvite("accepted"))
        assertEquals(false, canRevokeInvite("revoked"))
        assertEquals(false, canRevokeInvite("expired"))
    }

    @Test fun `email gate accepts well-formed and rejects malformed`() {
        assertEquals(true, isValidInviteEmail("admin@site-hospital.in"))
        assertEquals(true, isValidInviteEmail("  a.b@c.co  "))
        assertEquals(false, isValidInviteEmail("admin@site"))
        assertEquals(false, isValidInviteEmail("no-at-sign.in"))
        assertEquals(false, isValidInviteEmail("a b@c.in"))
        assertEquals(false, isValidInviteEmail(""))
    }
}
