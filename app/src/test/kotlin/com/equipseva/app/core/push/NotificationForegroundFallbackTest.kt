package com.equipseva.app.core.push

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import com.equipseva.app.navigation.DeepLinkRouter
import com.equipseva.app.navigation.NotificationDeepLink
import com.equipseva.app.navigation.Routes
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Foreground FCM tap behavior, synthetic and offline; sender extras are not authorization. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class NotificationForegroundFallbackTest {
    private val userA = "a1111111-1111-4111-8111-111111111111"
    private val userB = "b2222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val context: Application = ApplicationProvider.getApplicationContext()

    @Test fun unknown_missing_and_malformed_kinds_choose_the_safe_inbox() {
        val payloads = listOf(
            emptyMap(),
            mapOf("kind" to "future_kind"),
            mapOf("kind" to NotificationDeepLink.KIND_REPAIR_BID_ACCEPTED,
                "repair_job_id" to "../founder"),
        )
        payloads.forEach { data ->
            assertEquals(Routes.NOTIFICATIONS, notificationRouteForTap(data))
        }
    }

    @Test fun known_kind_keeps_its_existing_mapped_route() {
        assertEquals(
            Routes.repairJobDetailRoute("RPR-00027"),
            notificationRouteForTap(mapOf(
                "kind" to NotificationDeepLink.KIND_REPAIR_BID_ACCEPTED,
                "repair_job_id" to "RPR-00027",
            )),
        )
    }

    @Test fun foreground_unknown_kind_opens_inbox_only_for_matching_live_recipient() {
        val source = mockk<LoginTicketSource> { every { currentTicket() } returns ticketA }
        val router = DeepLinkRouter(source)
        val received = mutableListOf<String>()
        router.registerSink { received += it.route }
        val route = notificationRouteForTap(mapOf("kind" to "future_kind"))

        router.dispatch(notificationTapIntent(context, route,
            mapOf("user_id" to userB, "kind" to "future_kind")))
        router.dispatch(notificationTapIntent(context, route,
            mapOf("kind" to "future_kind")))
        assertTrue("Stale or missing recipient opened the inbox", received.isEmpty())

        router.dispatch(notificationTapIntent(context, route,
            mapOf("user_id" to userA, "kind" to "future_kind")))
        assertEquals(listOf(Routes.NOTIFICATIONS), received)
    }
}
