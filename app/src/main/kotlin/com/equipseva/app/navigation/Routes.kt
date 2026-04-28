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
    const val FOUNDER_REPORTS_QUEUE = "founder/reports"
    const val FOUNDER_USERS = "founder/users"
    const val FOUNDER_PAYMENTS = "founder/payments"
    const val FOUNDER_INTEGRITY = "founder/integrity"
    const val FOUNDER_CATEGORIES = "founder/categories"
    const val FOUNDER_BUYER_KYC = "founder/buyer_kyc"
    const val FOUNDER_ENGINEER_MAP = "founder/engineers_map"

    // Address book add/edit (sub-route of PROFILE_ADDRESSES). Optional id arg
    // distinguishes "new" from "edit existing".
    const val PROFILE_ADDRESS_FORM = "profile/addresses/form"
    const val PROFILE_ADDRESS_FORM_ARG_ID = "addressId"
    fun addressFormRoute(addressId: String? = null): String =
        if (addressId == null) PROFILE_ADDRESS_FORM else "$PROFILE_ADDRESS_FORM?addressId=$addressId"
}
