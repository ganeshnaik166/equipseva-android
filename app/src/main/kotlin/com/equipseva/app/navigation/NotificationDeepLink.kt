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
 *  - `chat_message_new`     → [Routes.chatRoute]            using `data["conversation_id"]`
 *  - `repair_bid_new`       → [Routes.repairJobDetailRoute] using `data["repair_job_id"]`
 *  - `repair_bid_accepted`  → [Routes.repairJobDetailRoute] using `data["repair_job_id"]`
 *  - `repair_bid_rejected`  → [Routes.repairJobDetailRoute] using `data["repair_job_id"]`
 *  - `repair_job_cancelled` → [Routes.repairJobDetailRoute] using `data["repair_job_id"]`
 *  - `kyc_status_changed`   → [Routes.KYC] (no id required — single-user screen)
 *
 * Marketplace-era kinds (`order_shipped`, `rfq_bid_accepted`) were
 * dropped along with the marketplace + RFQ surface in the v1 cleanup.
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
            KIND_REPAIR_BID_NEW,
            KIND_REPAIR_BID_ACCEPTED,
            KIND_REPAIR_BID_REJECTED,
            KIND_REPAIR_JOB_CANCELLED,
            // v2 cost-revision lifecycle — server emits these from
            // propose_cost_revision / decide_cost_revision (migration
            // 20260504130000). Repair job detail screen surfaces the
            // banner / decision sheet for the right side automatically.
            KIND_RATE_ENGINEER,
            KIND_RATE_HOSPITAL,
            KIND_COST_REVISION_PROPOSED,
            KIND_COST_REVISION_APPROVED,
            KIND_COST_REVISION_REJECTED,
            // PR-D9: 30-day warranty auto-flag — open the new job's
            // detail screen where the badge + waiver explanation lives.
            KIND_WARRANTY_COVERED ->
                data["repair_job_id"]?.takeIfUuid()?.let(Routes::repairJobDetailRoute)
            // KYC is a single-user screen — no id needed in payload, just open it.
            KIND_KYC_STATUS_CHANGED -> Routes.KYC
            // PR-D8: loyal hospital→engineer pair AMC upsell. Deep-links
            // to the engineer's public profile, which hosts the
            // "Set up monthly maintenance" CTA shipped in PR-C6.
            KIND_AMC_LOYAL_PAIR_NUDGE ->
                data["engineer_id"]?.takeIfUuid()?.let(Routes::engineerPublicProfileRoute)
            else -> null
        }
    }

    private fun String.takeIfUuid(): String? =
        takeIf { UUID_REGEX.matches(it) }

    // Kind constants — exposed so the messaging service / inbox tests can
    // reference them by name rather than by string literal.
    const val KIND_CHAT_MESSAGE_NEW = "chat_message_new"
    const val KIND_REPAIR_BID_NEW = "repair_bid_new"
    const val KIND_REPAIR_BID_ACCEPTED = "repair_bid_accepted"
    const val KIND_REPAIR_BID_REJECTED = "repair_bid_rejected"
    const val KIND_REPAIR_JOB_CANCELLED = "repair_job_cancelled"
    const val KIND_KYC_STATUS_CHANGED = "kyc_status_changed"
    // v2 — rating reminders + cost-revision lifecycle. All deep-link to
    // the repair job detail screen which renders the right CTA / banner
    // for the receiving side.
    const val KIND_RATE_ENGINEER = "rate_engineer"
    const val KIND_RATE_HOSPITAL = "rate_hospital"
    const val KIND_COST_REVISION_PROPOSED = "cost_revision_proposed"
    const val KIND_COST_REVISION_APPROVED = "cost_revision_approved"
    const val KIND_COST_REVISION_REJECTED = "cost_revision_rejected"
    // PR-D8 — server-side AMC upsell when a hospital→engineer pair
    // hits 3+ completed jobs without an active AMC contract.
    const val KIND_AMC_LOYAL_PAIR_NUDGE = "amc_loyal_pair_nudge"
    // PR-D9 — 30-day platform warranty auto-detection. Trigger fires
    // on INSERT when the new job matches a recently completed repair.
    const val KIND_WARRANTY_COVERED = "warranty_covered"
}
