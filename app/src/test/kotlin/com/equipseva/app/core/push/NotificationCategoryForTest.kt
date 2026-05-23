package com.equipseva.app.core.push

import androidx.core.app.NotificationCompat
import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationCategoryForTest {

    @Test fun `chat channel maps to CATEGORY_MESSAGE`() {
        // Critical pin — CATEGORY_MESSAGE is in most DND allow-lists by
        // default. A refactor that swapped this to SOCIAL would silently
        // suppress chat pushes for users with DND on.
        assertEquals(
            NotificationCompat.CATEGORY_MESSAGE,
            notificationCategoryFor(NotificationChannels.CHAT),
        )
    }

    @Test fun `jobs channel maps to CATEGORY_SOCIAL`() {
        assertEquals(
            NotificationCompat.CATEGORY_SOCIAL,
            notificationCategoryFor(NotificationChannels.JOBS),
        )
    }

    @Test fun `account channel maps to CATEGORY_STATUS`() {
        assertEquals(
            NotificationCompat.CATEGORY_STATUS,
            notificationCategoryFor(NotificationChannels.ACCOUNT),
        )
    }

    @Test fun `unknown channel falls back to CATEGORY_RECOMMENDATION`() {
        // Pin — defense-in-depth. resolvePushChannel already folds
        // unknown channels to ACCOUNT, but this helper must still
        // handle arbitrary strings gracefully without throwing.
        assertEquals(
            NotificationCompat.CATEGORY_RECOMMENDATION,
            notificationCategoryFor("unknown-channel"),
        )
    }

    @Test fun `empty channel string falls back to CATEGORY_RECOMMENDATION`() {
        assertEquals(
            NotificationCompat.CATEGORY_RECOMMENDATION,
            notificationCategoryFor(""),
        )
    }
}
