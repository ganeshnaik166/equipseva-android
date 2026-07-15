package com.equipseva.app.features.profile

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1402 consent action pill. */
class ConsentCentreHelpersTest {

    @Test fun `granted reads Granted with Success tone`() {
        assertEquals("Granted" to PillKind.Success, consentActionPillTextAndKind("granted"))
    }

    @Test fun `revoked reads Withdrawn with Neutral tone`() {
        assertEquals("Withdrawn" to PillKind.Neutral, consentActionPillTextAndKind("revoked"))
    }

    @Test fun `unknown action capitalises with Neutral tone`() {
        assertEquals("Pending" to PillKind.Neutral, consentActionPillTextAndKind("pending"))
    }
}
