package com.equipseva.app.core.data.notifications

import java.time.Instant

/**
 * Domain model for a single inbox notification. Mapped from the
 * `public.notifications` table; the wire DTO lives in [NotificationDto].
 *
 * `data` carries deep-link metadata (e.g. `{"deep_link": "..."}` or
 * `{"order_id": "..."}`). The screen consults it on tap to route the user
 * to the related surface; an empty map means the row is informational only.
 */
data class Notification(
    val id: String,
    val userId: String,
    val title: String,
    val body: String,
    val kind: String?,
    /** Free-form metadata for deep-link routing. Always non-null (possibly empty). */
    val data: Map<String, String>,
    /** Server-assigned send time. Null only on legacy rows; treat as epoch in that case. */
    val sentAt: Instant?,
    /** Null means unread. */
    val readAt: Instant?,
    /** Convenience pulled from `data["deep_link"]` or `action_url` fallback. */
    val deepLink: String?,
) {
    val isUnread: Boolean get() = readAt == null
}
