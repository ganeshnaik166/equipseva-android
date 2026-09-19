package com.equipseva.app.navigation

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A3-01 — pins the external-route allow-list. The reproduction that motivated
 * it: `adb shell am start -n com.equipseva.app/.MainActivity --es
 * com.equipseva.app.deeplink.ROUTE founder/dashboard` mounted founder UI for
 * any signed-in user. Every denied row here was navigable verbatim before.
 */
class DeepLinkPolicyTest {

    private val uuid = "11111111-2222-3333-4444-555555555555"

    @Test fun `fixed notification landings are allowed`() {
        listOf(
            Routes.HOME, Routes.PROFILE, Routes.KYC, Routes.NOTIFICATIONS,
            Routes.ENGINEER_DIRECTORY, Routes.ENGINEER_AMC_VISITS,
        ).forEach { assertTrue(it, DeepLinkPolicy.isExternallyAllowed(it)) }
    }

    @Test fun `id routes are allowed only with a strict id shape`() {
        assertTrue(DeepLinkPolicy.isExternallyAllowed(Routes.repairJobDetailRoute("RPR-00027")))
        assertTrue(DeepLinkPolicy.isExternallyAllowed(Routes.repairJobDetailRoute("rpr-1")))
        assertTrue(DeepLinkPolicy.isExternallyAllowed(Routes.repairJobDetailRoute(uuid)))
        assertTrue(DeepLinkPolicy.isExternallyAllowed(Routes.chatRoute(uuid)))
        assertTrue(DeepLinkPolicy.isExternallyAllowed(Routes.engineerPublicProfileRoute(uuid)))
        assertTrue(DeepLinkPolicy.isExternallyAllowed(Routes.amcContractDetailRoute(uuid)))

        assertFalse(DeepLinkPolicy.isExternallyAllowed(Routes.repairJobDetailRoute("RPR-123456789")))
        assertFalse(DeepLinkPolicy.isExternallyAllowed(Routes.repairJobDetailRoute("../founder")))
        assertFalse(DeepLinkPolicy.isExternallyAllowed(Routes.chatRoute("RPR-1")))
        assertFalse(DeepLinkPolicy.isExternallyAllowed(Routes.chatRoute("$uuid;hack")))
        assertFalse(DeepLinkPolicy.isExternallyAllowed("${Routes.REPAIR_DETAIL}/"))
        assertFalse(DeepLinkPolicy.isExternallyAllowed("${Routes.REPAIR_DETAIL}/RPR-1/extra"))
    }

    @Test fun `founder root auth onboarding and security routes are denied`() {
        listOf(
            Routes.FOUNDER_DASHBOARD,
            Routes.founderIntegrityRoute("00000000-0000-4000-8000-000000000001", "Attacker text"),
            Routes.founderKycReviewRoute(uuid),
            Routes.FOUNDER_ENGINEER_PAYOUTS,
            "root_main/x/engineer",
            "root_role/x",
            Routes.AUTH_WELCOME, Routes.AUTH_SIGN_IN, Routes.AUTH_GRAPH,
            Routes.HOSPITAL_PHONE_ONBOARDING, Routes.HOSPITAL_ONBOARDING, Routes.ENGINEER_ONBOARDING, Routes.TOUR,
            Routes.CHANGE_PASSWORD, Routes.CHANGE_EMAIL,
            Routes.ENGINEER_PAYOUT_METHOD, Routes.PROFILE_BANK_DETAILS, Routes.PROFILE_GST,
        ).forEach { assertFalse(it, DeepLinkPolicy.isExternallyAllowed(it)) }
        assertTrue(DeepLinkPolicy.isPrivileged(Routes.FOUNDER_DASHBOARD))
        assertTrue(DeepLinkPolicy.isPrivileged("root_main/x/engineer"))
        assertTrue(DeepLinkPolicy.isPrivileged(Routes.AUTH_SIGN_IN))
        assertFalse(DeepLinkPolicy.isPrivileged(Routes.HOME))
    }

    @Test fun `query strings encoded chars whitespace and blanks are denied`() {
        listOf(
            "", "  ", "home ", "home?x=1", "home#frag", "repair/detail/RPR-1?ref=x",
            "repair/detail/RPR%2D1", "chat/detail/$uuid\\", "notifications\n",
            Routes.requestSentRoute("j", "RPR-1"), Routes.hospitalAssetHistoryRoute("SN 1"),
        ).forEach { assertFalse("'$it'", DeepLinkPolicy.isExternallyAllowed(it)) }
        assertFalse(DeepLinkPolicy.isExternallyAllowed(null))
    }
}
