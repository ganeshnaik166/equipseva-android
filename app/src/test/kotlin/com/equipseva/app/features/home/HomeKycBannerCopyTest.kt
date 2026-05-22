package com.equipseva.app.features.home

import com.equipseva.app.core.data.engineers.VerificationStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the home-screen KYC banner copy. Three on-screen states:
 *
 *   * Pending — submitted, awaiting review ("Usually 24h" — pin the
 *     SLA hint copy so it stays aligned with the in-app KYC banner
 *     that promises "4–24 hours").
 *   * Rejected — admin flagged docs; engineer must re-upload.
 *   * Null / Verified / Unknown wire status — the "become an
 *     engineer" onboarding nudge.
 *
 * Critical region: the Pending/Rejected copy on this banner is the
 * engineer's first signal on app open that something needs their
 * attention. A regression that swapped them would either alarm a
 * just-submitted engineer or downplay a real re-upload requirement.
 */
class HomeKycBannerCopyTest {

    @Test fun `Pending shows under-review copy with 24h SLA hint`() {
        val copy = homeKycBannerCopy(VerificationStatus.Pending)
        assertEquals("KYC under review", copy.title)
        assertEquals("Usually 24h. We'll notify you.", copy.subtitle)
    }

    @Test fun `Rejected shows re-submit copy`() {
        val copy = homeKycBannerCopy(VerificationStatus.Rejected)
        assertEquals("KYC needs another try", copy.title)
        assertEquals("Re-submit the missing docs to enter the queue.", copy.subtitle)
    }

    @Test fun `null status shows onboarding nudge`() {
        val copy = homeKycBannerCopy(null)
        assertEquals("Become a verified engineer", copy.title)
        assertEquals("Submit KYC to start bidding on jobs.", copy.subtitle)
    }

    @Test fun `Verified status uses the onboarding fallback copy`() {
        // Verified is terminal — the screen-side composable doesn't
        // render the banner when the engineer is verified, but pin
        // the fallback copy so a refactor that drops the screen-side
        // gate doesn't silently render a confusing "become verified"
        // banner to an already-verified engineer.
        val copy = homeKycBannerCopy(VerificationStatus.Verified)
        assertEquals("Become a verified engineer", copy.title)
    }

    @Test fun `each state produces distinct title copy (no silent collapse)`() {
        val pending = homeKycBannerCopy(VerificationStatus.Pending).title
        val rejected = homeKycBannerCopy(VerificationStatus.Rejected).title
        val nullStatus = homeKycBannerCopy(null).title
        // Pin so a future refactor that merged the three branches
        // surfaces in review.
        val titles = setOf(pending, rejected, nullStatus)
        assertEquals(3, titles.size)
    }

    @Test fun `subtitles all promise concrete next-step actions`() {
        // Defensive — every subtitle should mention a verb the user
        // can act on (review / re-submit / submit / bid).
        val all = listOf(
            VerificationStatus.Pending,
            VerificationStatus.Rejected,
            null,
        ).map { homeKycBannerCopy(it).subtitle }
        all.forEach { subtitle ->
            val hasAction = listOf("review", "submit", "bid", "notify")
                .any { subtitle.contains(it, ignoreCase = true) }
            assertEquals("subtitle should suggest an action: $subtitle", true, hasAction)
        }
    }
}
