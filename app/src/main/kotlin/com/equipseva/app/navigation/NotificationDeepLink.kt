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

    // Human-readable repair-job code (RPR-NNNNN). Server may emit either
    // the UUID `id` or the public `job_number` for `repair_job_id`
    // payloads (PR #651 made the repository accept both for fetchById).
    // Match DeepLinkRouter.JOB_ID_REGEX so push + https deep links treat
    // the same id formats consistently.
    private val JOB_CODE_REGEX = Regex("^RPR-\\d{1,8}$", RegexOption.IGNORE_CASE)

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
            // PR-D12: engineer-side fee-waiver notification — same
            // destination (job detail surfaces the warranty banner).
            KIND_WARRANTY_COVERED,
            KIND_WARRANTY_FEE_WAIVED ->
                data["repair_job_id"]?.takeIfJobIdRoutable()?.let(Routes::repairJobDetailRoute)
            // KYC is a single-user screen — no id needed in payload, just open it.
            KIND_KYC_STATUS_CHANGED -> Routes.KYC
            // PR-D8: loyal hospital→engineer pair AMC upsell. Deep-links
            // to the engineer's public profile, which hosts the
            // "Set up monthly maintenance" CTA shipped in PR-C6.
            KIND_AMC_LOYAL_PAIR_NUDGE ->
                data["engineer_id"]?.takeIfUuid()?.let(Routes::engineerPublicProfileRoute)
            // PR-D11: cash-flag survey lands on the hospital home where
            // the modal sheet auto-opens via HomeHubViewModel.
            KIND_CASH_SURVEY -> Routes.HOME
            // PR-D43: spot-audit invitation lands on the hospital home —
            // same modal-sheet pattern as cash survey, sister auto-opener.
            KIND_SPOT_AUDIT_INVITED -> Routes.HOME
            // PR-D31: commission-tier upgrade celebration lands on Home.
            // Inline tier pill was pulled in round 136 with v1=free
            // monetization; route stays in place so the kind doesn't
            // 404 when v2 monetization re-emits.
            KIND_COMMISSION_TIER_UPGRADED -> Routes.HOME
            // PR-D11: engineer-side auto-suspend explainer. No
            // dedicated screen — Profile shows the suspended state via
            // the live `engineers.cash_auto_suspended_at` column.
            KIND_ENGINEER_AUTO_SUSPENDED -> Routes.PROFILE
            // PR-D21: admin queue alerts.
            KIND_ADMIN_ENGINEER_AUTO_SUSPENDED -> Routes.FOUNDER_CASH_SUSPENDED
            KIND_ADMIN_ESCROW_DISPUTE_OPENED -> Routes.FOUNDER_ESCROW_DISPUTES
            KIND_AMC_ADMIN_ESCALATION_RAISED -> Routes.FOUNDER_AMC_ESCALATIONS
            // PR-D22: engineer-side dispute alert. Open the repair job
            // detail where the EscrowStatusCard surfaces the dispute.
            KIND_ESCROW_DISPUTE_OPENED,
            // PR-D26: hospital is notified when the engineer posts a
            // response to a dispute. Same destination — the engineer's
            // response surfaces on the EscrowStatusCard.
            KIND_ESCROW_ENGINEER_RESPONDED,
            // PR-D28: both parties notified when admin resolves the
            // dispute. Same destination — the EscrowStatusCard reflects
            // the resolved status (released | refunded) inline.
            KIND_ESCROW_DISPUTE_RESOLVED ->
                data["repair_job_id"]?.takeIfJobIdRoutable()?.let(Routes::repairJobDetailRoute)
            // PR-C4: AMC SLA breach. Server payload carries the AMC
            // contract id; route to the contract detail where the SLA
            // tab renders the breach inline.
            KIND_AMC_SLA_BREACH ->
                data["amc_contract_id"]?.takeIfUuid()?.let(Routes::amcContractDetailRoute)
            // PR-C5: AMC visit assignment lifecycle. The visit IS a
            // repair_jobs row, so the per-job detail screen is the
            // right destination — engineer sees the new visit, hospital
            // sees who got assigned.
            KIND_AMC_VISIT_ASSIGNED,
            KIND_AMC_VISIT_ENGINEER_ASSIGNED,
            KIND_AMC_VISIT_ENGINEER_CHANGED ->
                data["repair_job_id"]?.takeIfJobIdRoutable()?.let(Routes::repairJobDetailRoute)
            // PR-C5: rotation exhausted, awaiting admin re-assignment.
            // Admins land on the escalations queue; non-admins see
            // contract detail.
            KIND_AMC_VISIT_PENDING_ASSIGNMENT ->
                data["amc_contract_id"]?.takeIfUuid()?.let(Routes::amcContractDetailRoute)
            else -> null
        }
    }

    private fun String.takeIfUuid(): String? =
        takeIf { UUID_REGEX.matches(it) }

    /** Accept either UUID `id` or RPR-NNNNN `job_number` per PR #651. */
    private fun String.takeIfJobIdRoutable(): String? =
        takeIf { UUID_REGEX.matches(it) || JOB_CODE_REGEX.matches(it) }

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
    // PR-D12 — engineer learns the platform absorbed the commission
    // on a warranty re-visit (their payout = full contracted amount).
    const val KIND_WARRANTY_FEE_WAIVED = "warranty_fee_waived"
    // PR-D1 — post-completion cash-payment survey on hospital home.
    const val KIND_CASH_SURVEY = "cash_survey"
    // PR-D43 — random 1-in-20 spot-audit invitation on hospital home.
    const val KIND_SPOT_AUDIT_INVITED = "spot_audit_invited"
    // PR-D31 — hospital crosses the 10-job (Loyal) or 50-job (Anchor)
    // commission tier threshold.
    const val KIND_COMMISSION_TIER_UPGRADED = "commission_tier_upgraded"
    // PR-D11 — engineer auto-suspended after 3+ cash flags / 90 days.
    const val KIND_ENGINEER_AUTO_SUSPENDED = "engineer_auto_suspended"
    const val KIND_ADMIN_ENGINEER_AUTO_SUSPENDED = "admin_engineer_auto_suspended"
    // PR-D22 — admin / engineer alert when hospital opens a dispute.
    const val KIND_ESCROW_DISPUTE_OPENED = "escrow_dispute_opened"
    const val KIND_ESCROW_ENGINEER_RESPONDED = "escrow_engineer_responded"
    const val KIND_ADMIN_ESCROW_DISPUTE_OPENED = "admin_escrow_dispute_opened"
    // PR-D28 — both parties notified when admin resolves a dispute.
    const val KIND_ESCROW_DISPUTE_RESOLVED = "escrow_dispute_resolved"
    // PR-D22 — admin alert when AMC rotation fully exhausted.
    const val KIND_AMC_ADMIN_ESCALATION_RAISED = "amc_admin_escalation_raised"
    // PR-C4 — AMC SLA breach on a maintenance visit.
    const val KIND_AMC_SLA_BREACH = "amc_sla_breach"
    // PR-C5 — AMC visit assignment lifecycle.
    const val KIND_AMC_VISIT_ASSIGNED = "amc_visit_assigned"
    const val KIND_AMC_VISIT_ENGINEER_ASSIGNED = "amc_visit_engineer_assigned"
    const val KIND_AMC_VISIT_ENGINEER_CHANGED = "amc_visit_engineer_changed"
    const val KIND_AMC_VISIT_PENDING_ASSIGNMENT = "amc_visit_pending_assignment"
}
