package com.equipseva.app.core.push

import android.app.Application
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.MainActivity
import com.equipseva.app.navigation.DeepLinkRouter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Synthetic notification-tap contract: no FCM service or real account is started. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class NotificationTapIntentTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val recipientA = "11111111-1111-4111-8111-111111111111"
    private val recipientB = "22222222-2222-4222-8222-222222222222"
    private val route = "repair/detail/RPR-00027"

    @Test fun route_tap_carries_server_recipient_without_copying_other_payload_fields() {
        val intent = notificationTapIntent(
            context,
            route,
            mapOf(
                "user_id" to recipientA,
                "kind" to "repair_bid_new",
                "body" to "Synthetic private body",
            ),
        )

        assertEquals(MainActivity::class.java.name, intent.component?.className)
        assertEquals(
            Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
            intent.flags,
        )
        assertEquals(route, intent.getStringExtra(DeepLinkRouter.EXTRA_ROUTE))
        // Desired A3-02 recipient contract. This assertion is RED until the
        // production builder binds the existing server-supplied user_id.
        assertEquals(recipientA, intent.getStringExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID))
        assertFalse(intent.hasExtra("kind"))
        assertFalse(intent.hasExtra("body"))
    }

    @Test fun tap_without_route_keeps_default_landing_and_no_recipient_extra() {
        val intent = notificationTapIntent(
            context,
            null,
            mapOf("user_id" to recipientA),
        )

        assertEquals(MainActivity::class.java.name, intent.component?.className)
        assertEquals(
            Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
            intent.flags,
        )
        assertFalse(intent.hasExtra(DeepLinkRouter.EXTRA_ROUTE))
        assertFalse(intent.hasExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID))
    }

    @Test fun route_without_recipient_does_not_invent_an_owner() {
        val intent = notificationTapIntent(context, route, emptyMap())

        assertEquals(route, intent.getStringExtra(DeepLinkRouter.EXTRA_ROUTE))
        assertFalse(intent.hasExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID))
        assertTrue(intent.component?.className == MainActivity::class.java.name)
    }

    @Test fun same_request_code_for_different_recipients_has_distinct_internal_intent_identity() {
        val first = notificationTapIntent(context, route, mapOf("user_id" to recipientA))
        val second = notificationTapIntent(
            context,
            "repair/detail/RPR-00028",
            mapOf("user_id" to recipientB),
        )

        // Two FCM messages with a null messageId both use request code 0 in
        // the production PendingIntent call. Extras do not enter filterEquals.
        val nullMessageId: String? = null
        assertEquals(0, nullMessageId.hashCode())
        assertFalse("Different push owners must not alias", first.filterEquals(second))

        val firstData = first.data
        val secondData = second.data
        assertNotNull(firstData)
        assertNotNull(secondData)
        assertNotEquals(firstData, secondData)
        listOf(firstData, secondData).forEach { uri ->
            assertFalse(uri?.scheme.equals("http", ignoreCase = true))
            assertFalse(uri?.scheme.equals("https", ignoreCase = true))
            assertNull(
                DeepLinkRouter.routeForParts(uri?.scheme, uri?.host, uri?.pathSegments.orEmpty()),
            )
        }
    }

    @Test fun same_request_code_does_not_update_another_recipient_pending_intent() {
        val first = notificationTapIntent(context, route, mapOf("user_id" to recipientA))
        val second = notificationTapIntent(
            context,
            "repair/detail/RPR-00028",
            mapOf("user_id" to recipientB),
        )
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val firstPending = PendingIntent.getActivity(context, 0, first, flags)
        val secondPending = PendingIntent.getActivity(context, 0, second, flags)
        try {
            assertNotEquals(
                "FLAG_UPDATE_CURRENT must not alias another recipient's tray action",
                firstPending,
                secondPending,
            )
        } finally {
            firstPending.cancel()
            secondPending.cancel()
        }
    }
}
