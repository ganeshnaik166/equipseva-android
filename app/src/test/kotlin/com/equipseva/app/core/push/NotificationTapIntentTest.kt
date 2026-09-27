package com.equipseva.app.core.push

import android.app.Application
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.MainActivity
import com.equipseva.app.navigation.DeepLinkRouter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
}
