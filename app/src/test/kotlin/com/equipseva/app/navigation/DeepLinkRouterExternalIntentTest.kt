package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** A3-01: an exported activity's extras are untrusted, including notification-shaped extras. */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, sdk = [35])
class DeepLinkRouterExternalIntentTest {
    private val uuid = "11111111-2222-3333-4444-555555555555"

    @Test fun external_extra_cannot_open_privileged_or_account_mutation_routes() = runTest {
        val denied = listOf(
            Routes.FOUNDER_DASHBOARD,
            "founder/integrity?user=$uuid&name=Injected",
            Routes.AUTH_SIGN_IN,
            Routes.HOSPITAL_PHONE_ONBOARDING,
            Routes.CHANGE_PASSWORD,
            Routes.CHANGE_EMAIL,
            Routes.ENGINEER_PAYOUT_METHOD,
            "root_main/$uuid/engineer",
        )
        denied.forEach { route ->
            val router = DeepLinkRouter()
            router.dispatch(intentWithRoute(route))
            assertNull("Untrusted extra opened $route", router.nextOrNull())
        }
    }

    @Test fun external_extra_rejects_malformed_ids_and_navigation_syntax() = runTest {
        val denied = listOf(
            "repair/detail/RPR-123456789",
            "repair/detail/RPR%2D1",
            "repair/detail/RPR-1/extra",
            "repair/detail/../founder",
            "chat/detail/RPR-1",
            "chat/detail/$uuid?source=other",
            "engineers/public/$uuid#profile",
            "amc/contract/$uuid\\path",
            "home ",
        )
        denied.forEach { route ->
            val router = DeepLinkRouter()
            router.dispatch(intentWithRoute(route))
            assertNull("Malformed route opened $route", router.nextOrNull())
        }
    }

    @Test fun legitimate_notification_and_app_link_destinations_still_open() = runTest {
        val accepted = listOf(
            Routes.HOME,
            Routes.PROFILE,
            Routes.NOTIFICATIONS,
            Routes.ENGINEER_DIRECTORY,
            Routes.repairJobDetailRoute("RPR-00027"),
            Routes.repairJobDetailRoute(uuid),
            Routes.chatRoute(uuid),
            Routes.engineerPublicProfileRoute(uuid),
            Routes.amcContractDetailRoute(uuid),
        )
        accepted.forEach { route ->
            val router = DeepLinkRouter()
            router.dispatch(intentWithRoute(route))
            assertEquals(route, (router.events.first() as DeepLinkRouter.Event.OpenRoute).route)
        }
    }

    @Test fun rejected_extra_does_not_hide_an_independently_valid_app_link() = runTest {
        val router = DeepLinkRouter()
        router.dispatch(intentWithRoute(Routes.FOUNDER_DASHBOARD).apply {
            data = Uri.parse("https://equipseva.com/notifications")
        })
        assertEquals(Routes.NOTIFICATIONS, (router.events.first() as DeepLinkRouter.Event.OpenRoute).route)
    }

    @Test fun founder_queue_notification_taps_fall_back_to_inbox() = runTest {
        val kinds = listOf(
            NotificationDeepLink.KIND_ADMIN_ENGINEER_AUTO_SUSPENDED,
            NotificationDeepLink.KIND_ADMIN_ESCROW_DISPUTE_OPENED,
            NotificationDeepLink.KIND_AMC_ADMIN_ESCALATION_RAISED,
        )
        kinds.forEach { kind ->
            val mapped = NotificationDeepLink.routeFor(kind, emptyMap())
            val router = DeepLinkRouter()
            router.dispatch(intentWithRoute(requireNotNull(mapped)))
            assertEquals(
                "Founder notification $kind must open a safe visible landing",
                Routes.NOTIFICATIONS,
                (router.events.first() as DeepLinkRouter.Event.OpenRoute).route,
            )
        }
    }

    @Test fun role_specific_notification_taps_fall_back_to_inbox() = runTest {
        val kinds = listOf(
            NotificationDeepLink.KIND_KYC_STATUS_CHANGED,
            NotificationDeepLink.KIND_AMC_VISIT_UNASSIGNED,
        )
        kinds.forEach { kind ->
            val mapped = NotificationDeepLink.routeFor(kind, emptyMap())
            val router = DeepLinkRouter()
            router.dispatch(intentWithRoute(requireNotNull(mapped)))
            assertEquals(
                "Role-specific notification $kind must open a safe visible landing",
                Routes.NOTIFICATIONS,
                (router.events.first() as DeepLinkRouter.Event.OpenRoute).route,
            )
        }
    }

    @Test fun valid_app_link_wins_over_founder_inbox_fallback() = runTest {
        val router = DeepLinkRouter()
        router.dispatch(intentWithRoute(Routes.FOUNDER_CASH_SUSPENDED).apply {
            data = Uri.parse("https://equipseva.com/job/RPR-00027")
        })
        assertEquals(
            Routes.repairJobDetailRoute("RPR-00027"),
            (router.events.first() as DeepLinkRouter.Event.OpenRoute).route,
        )
    }

    private fun intentWithRoute(route: String): Intent = Intent().putExtra(DeepLinkRouter.EXTRA_ROUTE, route)

    private suspend fun DeepLinkRouter.nextOrNull(): DeepLinkRouter.Event? =
        withTimeoutOrNull(50) { events.first() }
}
