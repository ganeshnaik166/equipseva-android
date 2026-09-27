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
 * A saved marker can lag behind MainActivity.setIntent(): save A, handle B in
 * onNewIntent, then die before the next save. A restored Intent B alone is not
 * evidence of a fresh delivery. This is a Robolectric ingress test, not an OS
 * process-death or FCM integration test.
 *
 * The two fail-closed targets reproduced RED as 4/2 before the restored-task
 * policy changed; the other cases preserve fresh and in-process delivery.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class RestoredTaskIngressLateIntentRaceTest {
    private val recipient = "a1111111-1111-4111-8111-111111111111"
    private val savedDelivery = "b2222222-2222-4222-8222-222222222222"
    private val laterDelivery = "c3333333-3333-4333-8333-333333333333"
    private val route = Routes.repairJobDetailRoute("RPR-00027")

    // Desired security behavior: no retained Activity owner or external
    // delivery proof remains after process death. The stale saved marker A
    // must not make the already-handled B appear fresh on restore.
    @Test fun restored_B_notification_after_save_A_and_handled_B_fails_closed() {
        val savedBeforeB = savedAfter(notificationTap(savedDelivery))
        val handledInProcess = notificationTap(laterDelivery)
        assertEquals(listOf(route), dispatchWhileAlive(handledInProcess))

        assertFalse(
            "A changed notification ID cannot prove B was not already handled before death",
            RestoredTaskIngress.shouldDispatch(savedBeforeB, Intent(handledInProcess)),
        )
    }

    @Test fun restored_B_raw_push_after_save_A_and_handled_B_fails_closed() {
        val savedBeforeB = savedAfter(rawPush(savedDelivery))
        val handledInProcess = rawPush(laterDelivery)
        assertEquals(listOf(route), dispatchWhileAlive(handledInProcess))

        assertFalse(
            "A changed raw-push ID cannot prove B was not already handled before death",
            RestoredTaskIngress.shouldDispatch(savedBeforeB, Intent(handledInProcess)),
        )
    }

    // Current-behavior characterization: MainActivity.onNewIntent directly
    // calls router.dispatch. A real B delivered while the Activity is alive
    // still reaches its registered owner; no saved-state gate is involved.
    @Test fun in_process_onNewIntent_dispatch_still_delivers_B_after_save_A() {
        val savedBeforeB = savedAfter(notificationTap(savedDelivery))
        val delivered = dispatchWhileAlive(notificationTap(laterDelivery))

        assertEquals(listOf(route), delivered)
        assertEquals(
            "No later save occurred: the marker must still identify A",
            RestoredTaskIngress.uniqueSavedDeliveryIdentity(savedBeforeB),
            RestoredTaskIngress.uniquePushIdentity(notificationTap(savedDelivery)),
        )
    }

    @Test fun genuinely_fresh_B_launch_with_no_saved_state_remains_eligible() {
        assertTrue(RestoredTaskIngress.shouldDispatch(null, notificationTap(laterDelivery)))
        assertTrue(RestoredTaskIngress.shouldDispatch(null, rawPush(laterDelivery)))
    }

    private fun dispatchWhileAlive(intent: Intent): List<String> {
        val router = router()
        val owner = DeepLinkRouter.LaunchOwner()
        val delivered = mutableListOf<String>()
        router.beginActivity(owner)
        val registration = router.registerSink(owner) { event ->
            delivered += event.route
        }
        try {
            router.dispatch(intent, owner)
            return delivered
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

    private fun rawPush(id: String): Intent = Intent(Intent.ACTION_MAIN)
        .putExtra("notification_id", id)
        .putExtra("kind", NotificationDeepLink.KIND_REPAIR_BID_ACCEPTED)
        .putExtra("repair_job_id", "RPR-00027")
        .putExtra("user_id", recipient)

    private fun router(): DeepLinkRouter {
        val ticket = LoginTicketSnapshot(
            recipient,
            "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        )
        val source = mockk<LoginTicketSource> {
            every { currentTicket() } returns ticket
        }
        return DeepLinkRouter(source)
    }
}
