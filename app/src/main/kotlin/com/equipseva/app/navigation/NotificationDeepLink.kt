package com.equipseva.app.navigation

/**
 * Maps a server-emitted notification (`kind` + `data` payload) to an
 * in-app navigation route string. The mapping is intentionally pure — it
 * takes only the strings FCM hands us (`remoteMessage.data` is always
 * `Map<String, String>`) and returns a route the existing [Routes] helpers
 * already speak. That keeps the resolver unit-testable without Android.
 *
 * Server-side push triggers (PR #192 — `*_push_event_triggers.sql`) tag
 * inserted notifications with one of these `kind` values plus an `id`
 * column inside the `data` JSONB. We honour any `kind` we recognise; for
 * an unknown / null `kind`, callers should fall back to the inbox so
 * users never get a dead tap.
 *
 * Recognised mappings:
 *  - `chat_message_new`   → [Routes.chatRoute] using `data["conversation_id"]`
 *  - `repair_bid_new`     → [Routes.repairJobDetailRoute] using `data["repair_job_id"]`
 *  - `order_shipped`      → [Routes.orderDetailRoute] using `data["order_id"]`
 *  - `rfq_bid_accepted`   → [Routes.hospitalRfqDetailRoute] using `data["rfq_id"]`
 *
 * Returns `null` if the kind is unknown OR the expected id is missing /
 * blank / not a UUID. Callers treat null as "show the inbox instead".
 */
object NotificationDeepLink {

    // RFC 4122 UUID, case-insensitive. We refuse anything else so a malformed
    // payload from the server can't push the user to a junk route.
    private val UUID_REGEX =
        Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

    /**
     * Resolve a route for the given push payload.
     *
     * @param kind The server's `kind` tag (e.g. `chat_message_new`). May be null.
     * @param data Raw FCM data map. Values are always strings on the wire.
     * @return A route string ready for `navController.navigate(...)`, or
     *   `null` if the resolver doesn't recognise the kind or the required
     *   id field is missing / invalid.
     */
    fun routeFor(kind: String?, data: Map<String, String>): String? {
        if (kind.isNullOrBlank()) return null
        return when (kind) {
            KIND_CHAT_MESSAGE_NEW -> data["conversation_id"]?.takeIfUuid()?.let(Routes::chatRoute)
            KIND_REPAIR_BID_NEW -> data["repair_job_id"]?.takeIfUuid()?.let(Routes::repairJobDetailRoute)
            KIND_ORDER_SHIPPED -> data["order_id"]?.takeIfUuid()?.let(Routes::orderDetailRoute)
            KIND_RFQ_BID_ACCEPTED -> data["rfq_id"]?.takeIfUuid()?.let(Routes::hospitalRfqDetailRoute)
            else -> null
        }
    }

    private fun String.takeIfUuid(): String? =
        takeIf { UUID_REGEX.matches(it) }

    // Kind constants — exposed so the messaging service / inbox tests can
    // reference them by name rather than by string literal.
    const val KIND_CHAT_MESSAGE_NEW = "chat_message_new"
    const val KIND_REPAIR_BID_NEW = "repair_bid_new"
    const val KIND_ORDER_SHIPPED = "order_shipped"
    const val KIND_RFQ_BID_ACCEPTED = "rfq_bid_accepted"
}
