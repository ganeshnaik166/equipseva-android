package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Background notification+data messages bypass FirebaseMessagingService and
 * put the sender's raw data keys on the launcher Intent. These are untrusted
 * exported-activity inputs, not proof that FCM sent the Intent.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, sdk = [35])
class DeepLinkSystemTrayIntentTest {
    private val accountA = "a1111111-1111-4111-8111-111111111111"
    private val accountB = "b2222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(accountA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val ticketB = LoginTicketSnapshot(accountB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val notificationId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"

    @Test fun matching_background_job_tap_uses_sender_keys_without_custom_route_extra() {
        val (router, received) = mounted(ticketA)
        router.dispatch(rawPush(
            NotificationDeepLink.KIND_REPAIR_BID_ACCEPTED,
            accountA,
            "repair_job_id" to "RPR-00027",
        ))

        assertEquals(listOf(Routes.repairJobDetailRoute("RPR-00027")), received)
    }

    @Test fun matching_background_chat_and_amc_taps_use_strict_known_ids() {
        val (router, received) = mounted(ticketA)
        val chatId = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
        val amcId = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"

        router.dispatch(rawPush(NotificationDeepLink.KIND_CHAT_MESSAGE_NEW, accountA,
            "conversation_id" to chatId))
        router.dispatch(rawPush(NotificationDeepLink.KIND_AMC_SLA_BREACH, accountA,
            "amc_contract_id" to amcId))

        assertEquals(listOf(Routes.chatRoute(chatId), Routes.amcContractDetailRoute(amcId)), received)
    }

    @Test fun unknown_kind_and_invalid_id_land_only_in_matching_accounts_inbox() {
        val (router, received) = mounted(ticketA)
        router.dispatch(rawPush("future_kind", accountA))
        router.dispatch(rawPush(NotificationDeepLink.KIND_CHAT_MESSAGE_NEW, accountA,
            "conversation_id" to "../founder"))

        assertEquals(listOf(Routes.NOTIFICATIONS, Routes.NOTIFICATIONS), received)
    }

    @Test fun privileged_push_kind_uses_inbox_fallback_instead_of_direct_founder_route() {
        val (router, received) = mounted(ticketA)
        router.dispatch(rawPush(NotificationDeepLink.KIND_ADMIN_ENGINEER_AUTO_SUSPENDED, accountA))

        assertEquals(listOf(Routes.NOTIFICATIONS), received)
    }

    @Test fun stale_missing_and_wrong_type_recipients_never_open_a_background_push() {
        val (router, received) = mounted(ticketB)
        router.dispatch(rawPush(NotificationDeepLink.KIND_REPAIR_BID_NEW, accountA,
            "repair_job_id" to "RPR-00027"))
        router.dispatch(rawPush(NotificationDeepLink.KIND_REPAIR_BID_NEW, null,
            "repair_job_id" to "RPR-00027"))
        router.dispatch(rawPush(NotificationDeepLink.KIND_REPAIR_BID_NEW, accountB.uppercase(),
            "repair_job_id" to "RPR-00027"))
        router.dispatch(rawPush(NotificationDeepLink.KIND_REPAIR_BID_NEW, null,
            "repair_job_id" to "RPR-00027").putExtra("user_id", 42))

        assertTrue(received.isEmpty())
        router.dispatch(rawPush(NotificationDeepLink.KIND_REPAIR_BID_NEW, accountB,
            "repair_job_id" to "RPR-00028"))
        assertEquals(listOf(Routes.repairJobDetailRoute("RPR-00028")), received)
    }

    @Test fun valid_https_app_link_beats_stale_or_unknown_raw_push_fallback() {
        val (router, received) = mounted(ticketB)
        router.dispatch(rawPush("future_kind", accountA).apply {
            data = Uri.parse("https://equipseva.com/notifications")
        })

        assertEquals(listOf(Routes.NOTIFICATIONS), received)
    }

    @Test fun valid_https_app_link_beats_a_valid_matching_raw_job_route() {
        val (router, received) = mounted(ticketA)
        router.dispatch(rawPush(NotificationDeepLink.KIND_REPAIR_BID_ACCEPTED, accountA,
            "repair_job_id" to "RPR-00027").apply {
            data = Uri.parse("https://equipseva.com/notifications")
        })

        assertEquals(listOf(Routes.NOTIFICATIONS), received)
    }

    @Test fun conflicting_custom_and_raw_push_sources_are_rejected_but_app_link_survives() {
        val (router, received) = mounted(ticketA)
        val conflicting = rawPush(NotificationDeepLink.KIND_CHAT_MESSAGE_NEW, accountA,
            "conversation_id" to "dddddddd-dddd-4ddd-8ddd-dddddddddddd")
            .putExtra(DeepLinkRouter.EXTRA_ROUTE, Routes.HOME)
            .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, accountA)
        router.dispatch(conflicting)
        assertTrue(received.isEmpty())

        conflicting.data = Uri.parse("https://equipseva.com/notifications")
        router.dispatch(conflicting)
        assertEquals(listOf(Routes.NOTIFICATIONS), received)
    }

    @Test fun raw_deep_link_string_cannot_inject_an_unmapped_route() {
        val (router, received) = mounted(ticketA)
        router.dispatch(rawPush("future_kind", accountA,
            "deep_link" to Routes.FOUNDER_DASHBOARD))

        assertEquals(listOf(Routes.NOTIFICATIONS), received)
    }

    private fun mounted(ticket: LoginTicketSnapshot): Pair<DeepLinkRouter, MutableList<String>> {
        val source = mockk<LoginTicketSource> { every { currentTicket() } returns ticket }
        val router = DeepLinkRouter(source)
        val received = mutableListOf<String>()
        router.registerSink { received += it.route }
        return router to received
    }

    private fun rawPush(kind: String, recipient: String?, vararg selectors: Pair<String, String>): Intent =
        Intent().putExtra("notification_id", notificationId).putExtra("kind", kind).apply {
            if (recipient != null) putExtra("user_id", recipient)
            selectors.forEach { (key, value) -> putExtra(key, value) }
        }
}
