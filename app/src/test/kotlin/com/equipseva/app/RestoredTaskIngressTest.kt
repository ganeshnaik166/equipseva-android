package com.equipseva.app

import android.app.Application
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import com.equipseva.app.navigation.DeepLinkRouter
import com.equipseva.app.navigation.NotificationDeepLink
import com.equipseva.app.navigation.Routes
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Restored Activity state can carry an old launch Intent, while a new external tap
 * can also create the Activity with saved state. These tests exercise the small
 * ingress decision without booting MainActivity's Hilt, Compose, and SDK graph.
 * The router remains responsible for route policy and login ownership.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class RestoredTaskIngressTest {
    private val recipient = "a1111111-1111-4111-8111-111111111111"
    private val oldDelivery = "b2222222-2222-4222-8222-222222222222"
    private val newDelivery = "c3333333-3333-4333-8333-333333333333"
    private val ticket = LoginTicketSnapshot(
        recipient,
        "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    )
    private val route = Routes.repairJobDetailRoute("RPR-00027")

    @Test fun fresh_launch_is_still_eligible_for_startup_dispatch() {
        assertTrue(RestoredTaskIngress.shouldDispatch(null, Intent(Intent.ACTION_MAIN)))
        assertTrue(RestoredTaskIngress.shouldDispatch(null, notificationTap(oldDelivery)))
        assertTrue(RestoredTaskIngress.shouldDispatch(null, appLink("RPR-00027")))
        assertTrue(RestoredTaskIngress.shouldDispatch(null, rawBackgroundTap(oldDelivery)))
    }

    @Test fun saved_old_notification_app_link_and_raw_push_do_not_ghost_replay() {
        listOf(
            Intent(Intent.ACTION_MAIN),
            notificationTap(oldDelivery),
            appLink("RPR-00027"),
            rawBackgroundTap(oldDelivery),
        ).forEach { oldIntent ->
            val saved = savedAfter(oldIntent)
            assertFalse(
                "A restored copy of the previous launch must not navigate again",
                RestoredTaskIngress.shouldDispatch(saved, Intent(oldIntent)),
            )
        }
    }

    @Test fun restored_launcher_task_accepts_each_new_external_tap_format() {
        val saved = savedAfter(Intent(Intent.ACTION_MAIN))

        assertTrue(RestoredTaskIngress.shouldDispatch(saved, notificationTap(newDelivery)))
        assertTrue(RestoredTaskIngress.shouldDispatch(saved, appLink("RPR-00027")))
        assertTrue(RestoredTaskIngress.shouldDispatch(saved, rawBackgroundTap(newDelivery)))
    }

    @Test fun new_notification_identity_is_distinct_from_the_saved_notification() {
        assertTrue(RestoredTaskIngress.shouldDispatch(
            savedAfter(notificationTap(oldDelivery)),
            notificationTap(newDelivery),
        ))
        assertTrue(RestoredTaskIngress.shouldDispatch(
            savedAfter(rawBackgroundTap(oldDelivery)),
            rawBackgroundTap(newDelivery),
        ))
    }

    @Test fun changed_app_link_opens_but_identical_url_fails_closed_after_restore() {
        val saved = savedAfter(appLink("RPR-00027"))

        assertTrue(RestoredTaskIngress.shouldDispatch(saved, appLink("RPR-00028")))
        // There is no OS delivery nonce for App Links. An identical second tap
        // cannot be distinguished from Android restoring the prior Intent.
        assertFalse(RestoredTaskIngress.shouldDispatch(saved, appLink("RPR-00027")))
    }

    @Test fun missing_saved_identity_and_malformed_raw_id_fail_closed_without_crashing() {
        val malformedRaw = rawBackgroundTap(newDelivery).putExtra("notification_id", 42)
        val missingRaw = rawBackgroundTap(newDelivery).apply { removeExtra("notification_id") }

        assertFalse(RestoredTaskIngress.shouldDispatch(Bundle(), notificationTap(newDelivery)))
        assertFalse(RestoredTaskIngress.shouldDispatch(
            savedAfter(Intent(Intent.ACTION_MAIN)),
            malformedRaw,
        ))
        assertFalse(RestoredTaskIngress.shouldDispatch(
            savedAfter(Intent(Intent.ACTION_MAIN)),
            missingRaw,
        ))
    }

    @Test fun malformed_push_extra_does_not_hide_an_independent_new_app_link() {
        val saved = savedAfter(Intent(Intent.ACTION_MAIN))
        val link = appLink("RPR-00027")
            .putExtra(DeepLinkRouter.EXTRA_ROUTE, 42)

        assertTrue(RestoredTaskIngress.shouldDispatch(saved, link))
        assertEquals(listOf(route), startupRoutes(link))
    }

    @Test fun fresh_restored_tap_still_passes_through_exported_route_policy() {
        val saved = savedAfter(Intent(Intent.ACTION_MAIN))
        val malicious = notificationTap(newDelivery)
            .putExtra(DeepLinkRouter.EXTRA_ROUTE, Routes.FOUNDER_DASHBOARD)

        assertTrue(RestoredTaskIngress.shouldDispatch(saved, malicious))
        assertTrue(startupRoutes(malicious).isEmpty())
    }

    @Test fun ordinary_on_new_intent_router_dispatch_remains_live() {
        val router = router()
        val owner = DeepLinkRouter.LaunchOwner()
        router.beginActivity(owner)
        val delivered = mutableListOf<String>()
        val registration = router.registerSink(owner) { delivered += it.route }
        try {
            router.dispatch(notificationTap(newDelivery), owner)
            assertEquals(listOf(route), delivered)
        } finally {
            registration.close()
            router.endActivity(owner)
        }
    }

    private fun savedAfter(intent: Intent): Bundle = Bundle().also {
        RestoredTaskIngress.record(it, intent)
    }

    private fun notificationTap(id: String): Intent = Intent()
        .setData(Uri.parse("equipseva-internal-notification://tap/$id"))
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, recipient)

    private fun appLink(jobNumber: String): Intent = Intent(Intent.ACTION_VIEW)
        .setData(Uri.parse("https://equipseva.com/job/$jobNumber"))

    private fun rawBackgroundTap(id: String): Intent = Intent(Intent.ACTION_MAIN)
        .putExtra("notification_id", id)
        .putExtra("kind", NotificationDeepLink.KIND_REPAIR_BID_ACCEPTED)
        .putExtra("repair_job_id", "RPR-00027")
        .putExtra("user_id", recipient)

    private fun router(): DeepLinkRouter {
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } returns ticket
        }
        return DeepLinkRouter(source)
    }

    private fun startupRoutes(intent: Intent): List<String> {
        val router = router()
        val owner = DeepLinkRouter.LaunchOwner()
        router.beginActivity(owner)
        val delivered = mutableListOf<String>()
        val registration = router.registerSink(owner) { delivered += it.route }
        try {
            router.dispatchStartup(intent, owner)
            return delivered
        } finally {
            registration.close()
            router.endActivity(owner)
        }
    }
}
