package com.equipseva.app.features.security

import com.equipseva.app.features.profile.profileProviderReauthMessage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

/**
 * Copy for an account that has no password to confirm with.
 *
 * A Google-only sign-up has no password identity, so a password re-auth can
 * only ever fail. Reporting that as "Current password is incorrect." left
 * those users unable to change their email or delete their account, with
 * nothing on screen explaining why — so the copy has to name the provider and
 * point at the only re-auth that can work.
 */
class ProviderReauthRequiredMessageTest {

    @Test fun `names the provider and the affordance that works`() {
        assertEquals(
            "This account signs in with Google, so there is no password to confirm. " +
                "Use Continue with Google to confirm it is you.",
            providerReauthRequiredMessage("google"),
        )
    }

    @Test fun `never blames the password`() {
        val msg = providerReauthRequiredMessage("google")
        assertTrue(msg.contains("no password to confirm"))
        assertTrue(!msg.contains("incorrect", ignoreCase = true))
    }

    @Test fun `provider casing does not depend on the device locale`() {
        // Turkish lower-cases I to a dotless ı; a locale-sensitive
        // capitalisation would render provider labels differently per device.
        val original = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("tr-TR"))
            assertTrue(providerReauthRequiredMessage("iCloud").contains("ICloud"))
        } finally {
            Locale.setDefault(original)
        }
    }

    @Test fun `an unknown provider falls back to the one we ship`() {
        // Google is the only OAuth provider wired into sign-in, so a blank
        // provider name must still produce actionable copy.
        assertEquals(providerReauthRequiredMessage("google"), providerReauthRequiredMessage("  "))
    }

    @Test fun `the delete-account sheet says exactly the same thing`() {
        // Two screens describing one account state two different ways reads as
        // two different problems; these copies must not drift apart.
        listOf("google", "apple", "   ").forEach { provider ->
            assertEquals(
                providerReauthRequiredMessage(provider),
                profileProviderReauthMessage(provider),
            )
        }
    }
}
