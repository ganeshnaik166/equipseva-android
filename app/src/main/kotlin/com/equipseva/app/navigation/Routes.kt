package com.equipseva.app.navigation

object Routes {
    // Top-level graph IDs (sub-graphs wrapped under these names).
    const val AUTH_GRAPH = "auth_graph"

    // Auth sub-routes — email + password is the primary sign-in path; Google
    // sign-in (OIDC via Credential Manager) is the alternative; forgot-password
    // fires a Supabase reset email.
    const val AUTH_WELCOME = "auth/welcome"
    const val AUTH_SIGN_IN = "auth/sign_in"
    const val AUTH_SIGN_UP = "auth/sign_up"
    const val AUTH_FORGOT_PASSWORD = "auth/forgot_password"

    // Post-login security flows (entered from Profile).
    const val CHANGE_PASSWORD = "security/change_password"
    const val CHANGE_EMAIL = "security/change_email"

    // Main bottom-tab routes. v1: Home / Repair / Profile only — Buy/Sell tab
    // is gone with the marketplace, orders, cart, checkout cleanup.
    const val HOME = "home"
    const val REPAIR = "repair"
    const val PROFILE = "profile"

    // Repair job detail (sub-route, full-screen — bottom nav hidden).
    const val REPAIR_DETAIL = "repair/detail"
    const val REPAIR_DETAIL_ARG_ID = "jobId"
    fun repairJobDetailRoute(jobId: String): String = "$REPAIR_DETAIL/$jobId"

    // Chat — conversation list and single-thread view (both full-screen).
    const val CONVERSATIONS = "chat"
    const val CHAT_DETAIL = "chat/detail"
    const val CHAT_DETAIL_ARG_ID = "conversationId"
    fun chatRoute(conversationId: String): String = "$CHAT_DETAIL/$conversationId"

    // Engineer KYC / verification (full-screen, engineer-only entry from Profile).
    const val KYC = "profile/kyc"

    // Post-submit confirmation screen for KYC. Reached from KycScreen on
    // successful upsert; routes back to Home on tap.
    const val KYC_SUBMITTED = "profile/kyc/submitted"

    // About screen (version, licenses, links — sub-route entered from Profile).
    const val ABOUT = "profile/about"

    // Add (or change) phone number for an already-signed-in user. Surfaced
    // from KYC Step 1 + Profile when the engineer's profile is missing a
    // phone or wants to change it (always OTP-verified).
    const val ADD_PHONE = "profile/add_phone"

    // Engineer-specific dashboards (full-screen sub-routes entered from Home).
    const val MY_BIDS = "engineer/my_bids"
    const val EARNINGS = "engineer/earnings"
    const val ACTIVE_WORK = "engineer/active_work"
    const val ENGINEER_PROFILE = "engineer/profile"

    // Hospital-side sub-routes.
    const val REQUEST_SERVICE = "hospital/request_service"
    const val HOSPITAL_ACTIVE_JOBS = "hospital/active_jobs"

    // Confirmation landing after a successful repair-job submit. Optional
    // jobId + jobNumber query args drive the "View job" CTA + display copy.
    const val REQUEST_SENT = "hospital/request_sent"
    fun requestSentRoute(jobId: String?, jobNumber: String?): String {
        val params = buildList {
            if (!jobId.isNullOrBlank()) add("jobId=$jobId")
            if (!jobNumber.isNullOrBlank()) add("jobNumber=$jobNumber")
        }
        return if (params.isEmpty()) REQUEST_SENT else "$REQUEST_SENT?${params.joinToString("&")}"
    }

    // Engineer Jobs hub — chooser landing for an engineer's daily workflow
    // (available jobs, my bids, active work, earnings, profile editor).
    const val ENGINEER_JOBS_HUB = "engineer/jobs_hub"

    // Standalone editor for engineer base coords (engineers.latitude/longitude).
    // Reachable from the Jobs hub. Lets the engineer move their service centre
    // without going back through the full KYC flow.
    const val ENGINEER_LOCATION = "engineer/service_location"

    // Book Repair — public engineer directory (entry from Home Hub).
    const val ENGINEER_DIRECTORY = "engineers/directory"

    // Public-facing engineer profile (hospital views before contacting).
    const val ENGINEER_PUBLIC_PROFILE = "engineers/public"
    const val ENGINEER_PUBLIC_PROFILE_ARG_ID = "engineerId"
    fun engineerPublicProfileRoute(engineerId: String): String =
        "$ENGINEER_PUBLIC_PROFILE/$engineerId"

    // Notifications inbox (live feed of in-app notifications, realtime-backed).
    const val NOTIFICATIONS = "notifications"

    // First-run feature tour. Shown once per device install AFTER role pick,
    // before the user lands in MainNavGraph. Gated by `userPrefs.tourSeen`.
    const val TOUR = "onboarding/tour"

    // Notification settings (per-category push mute toggles, persisted to
    // DataStore). Split from the inbox so the two surfaces can evolve
    // independently — the inbox is read-side data; settings is local prefs.
    const val NOTIFICATION_SETTINGS = "notifications/settings"

    // Founder admin surfaces. Email-pinned to ganesh1431.dhanavath@gmail.com
    // via Profile.isFounder(); server-side enforcement happens via the
    // is_founder() SQL function on every privileged RPC. Hidden on the
    // bottom nav for non-founders; entered from a Profile row for the
    // founder.
    // Per-role profile sub-screens. Real forms land per-role; this batch
    // ships placeholder shells so the Profile rows actually navigate.
    const val PROFILE_BANK_DETAILS = "profile/bank_details"
    const val PROFILE_ADDRESSES = "profile/addresses"
    const val PROFILE_HOSPITAL_SETTINGS = "profile/hospital_settings"
    const val PROFILE_STOREFRONT = "profile/storefront"
    const val PROFILE_GST = "profile/gst"
    const val PROFILE_BRAND_PORTFOLIO = "profile/brand_portfolio"
    const val PROFILE_TAX_DETAILS = "profile/tax_details"
    const val PROFILE_VEHICLE_DETAILS = "profile/vehicle_details"
    const val PROFILE_LICENCE = "profile/licence"
    const val PROFILE_SERVICE_AREAS = "profile/service_areas"

    const val FOUNDER_DASHBOARD = "founder/dashboard"
    const val FOUNDER_KYC_QUEUE = "founder/kyc"
    const val FOUNDER_KYC_REVIEW = "founder/kyc/review"
    const val FOUNDER_KYC_REVIEW_ARG_USER_ID = "userId"
    fun founderKycReviewRoute(userId: String): String = "$FOUNDER_KYC_REVIEW/$userId"
    const val FOUNDER_REPORTS_QUEUE = "founder/reports"
    const val FOUNDER_USERS = "founder/users"
    const val FOUNDER_PAYMENTS = "founder/payments"
    const val FOUNDER_INTEGRITY = "founder/integrity"
    // Round 360 — optional buyer filter so the r351 Payments-row pill
    // can tap-through. Both params optional; absence = full list.
    const val FOUNDER_INTEGRITY_ARG_USER = "user"
    const val FOUNDER_INTEGRITY_ARG_NAME = "name"
    fun founderIntegrityRoute(userId: String? = null, name: String? = null): String {
        if (userId.isNullOrBlank()) return FOUNDER_INTEGRITY
        val q = buildString {
            append("?").append(FOUNDER_INTEGRITY_ARG_USER).append('=')
            append(java.net.URLEncoder.encode(userId, "UTF-8"))
            if (!name.isNullOrBlank()) {
                append('&').append(FOUNDER_INTEGRITY_ARG_NAME).append('=')
                append(java.net.URLEncoder.encode(name, "UTF-8"))
            }
        }
        return FOUNDER_INTEGRITY + q
    }
    const val FOUNDER_CATEGORIES = "founder/categories"
    const val FOUNDER_BUYER_KYC = "founder/buyer_kyc"
    const val FOUNDER_ENGINEER_MAP = "founder/engineers_map"
    // Round 364 — drill-down for the dashboard r352 "Expiring 30d" KPI.
    const val FOUNDER_AMC_EXPIRING = "founder/amc_expiring"
    // v2.1 PR-D21 ops queues — surface admin RPCs that previously had no UI.
    const val FOUNDER_ESCROW_DISPUTES = "founder/escrow_disputes"
    const val FOUNDER_AMC_ESCALATIONS = "founder/amc_escalations"
    const val FOUNDER_CASH_SUSPENDED = "founder/cash_suspended"
    const val FOUNDER_PARTS_OUTLIERS = "founder/parts_outliers"

    // v2.1 PR-D24 — engineer drill-down from the money-in-flight card.
    const val ENGINEER_ACTIVE_ESCROWS = "engineer/escrows/active"

    // v2.1 PR-D25 — admin drill-down on cash-flag suspended engineer rows.
    const val FOUNDER_CASH_FLAG_HISTORY = "founder/cash_flag_history"
    const val FOUNDER_CASH_FLAG_HISTORY_ARG_ENGINEER_ID = "engineerId"
    fun founderCashFlagHistoryRoute(engineerId: String): String =
        "$FOUNDER_CASH_FLAG_HISTORY/$engineerId"

    // v2.1 PR-D26 — admin drill-down on escrow dispute event timeline.
    const val FOUNDER_ESCROW_DISPUTE_DETAIL = "founder/escrow_dispute_detail"
    const val FOUNDER_ESCROW_DISPUTE_DETAIL_ARG_ESCROW_ID = "escrowId"
    fun founderEscrowDisputeDetailRoute(escrowId: String): String =
        "$FOUNDER_ESCROW_DISPUTE_DETAIL/$escrowId"

    // v2.1 PR-D27 — admin drill-down on AMC escalation w/ rotation roster.
    const val FOUNDER_AMC_ESCALATION_DETAIL = "founder/amc_escalation_detail"
    const val FOUNDER_AMC_ESCALATION_DETAIL_ARG_ESCALATION_ID = "escalationId"
    fun founderAmcEscalationDetailRoute(escalationId: String): String =
        "$FOUNDER_AMC_ESCALATION_DETAIL/$escalationId"

    // v2.1 PR-D40 — admin ledger of recently resolved escrow disputes.
    const val FOUNDER_RESOLVED_DISPUTES = "founder/resolved_disputes"

    // v2.1 PR-D43 — admin view of recent spot-audit responses.
    const val FOUNDER_SPOT_AUDITS = "founder/spot_audits"

    // v2.1 PR-D33 — engineer's AMC visit list.
    const val ENGINEER_AMC_VISITS = "engineer/amc_visits"

    // v2.1 PR-D41 — hospital self-view of their dispute filing history.
    const val HOSPITAL_MY_DISPUTES = "hospital/my_disputes"

    // v2.1 PR-D42 — engineer self-view of disputes received.
    const val ENGINEER_MY_DISPUTES = "engineer/my_disputes"

    // Address book add/edit (sub-route of PROFILE_ADDRESSES). Optional id arg
    // distinguishes "new" from "edit existing".
    const val PROFILE_ADDRESS_FORM = "profile/addresses/form"
    const val PROFILE_ADDRESS_FORM_ARG_ID = "addressId"
    fun addressFormRoute(addressId: String? = null): String =
        if (addressId == null) PROFILE_ADDRESS_FORM else "$PROFILE_ADDRESS_FORM?addressId=$addressId"

    // v2.1 PR-C6 — AMC (Annual Maintenance Contract) surfaces.
    // Hospital opens AMC_CONTRACTS_LIST from the Profile menu; from a
    // verified engineer's public profile they can launch CREATE_AMC
    // pre-filled with that engineer as primary; tapping a list row
    // navigates to AMC_CONTRACT_DETAIL.
    const val AMC_CONTRACTS_LIST = "amc/contracts"
    const val AMC_CONTRACT_DETAIL = "amc/contract"
    const val AMC_CONTRACT_DETAIL_ARG_ID = "contractId"
    fun amcContractDetailRoute(contractId: String): String =
        "$AMC_CONTRACT_DETAIL/$contractId"

    const val CREATE_AMC = "amc/create"
    const val CREATE_AMC_ARG_ENGINEER_ID = "engineerId"
    // Round 315 — optional query arg: when the user lands on the wizard
    // from the Renew CTA we pass the prior contract id so the ViewModel
    // can pre-populate scope/frequency/fee/categories from it.
    const val CREATE_AMC_ARG_SOURCE_ID = "sourceContractId"
    fun createAmcRoute(engineerId: String): String =
        "$CREATE_AMC/$engineerId"

    fun createAmcRouteWithSource(engineerId: String, sourceContractId: String): String =
        "$CREATE_AMC/$engineerId?$CREATE_AMC_ARG_SOURCE_ID=$sourceContractId"
}
