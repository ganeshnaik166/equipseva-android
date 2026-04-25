package com.equipseva.app.navigation

object Routes {
    // Top-level graph IDs (sub-graphs wrapped under these names).
    const val AUTH_GRAPH = "auth_graph"

    // Auth sub-routes.
    const val AUTH_WELCOME = "auth/welcome"
    const val AUTH_SIGN_IN = "auth/sign_in"
    const val AUTH_SIGN_UP = "auth/sign_up"
    const val AUTH_OTP_REQUEST = "auth/otp_request"
    const val AUTH_OTP_VERIFY = "auth/otp_verify"
    const val AUTH_FORGOT_PASSWORD = "auth/forgot_password"

    // OTP verify takes the email as a path arg so the back stack is restorable.
    const val AUTH_OTP_VERIFY_ARG_EMAIL = "email"
    fun otpVerifyRoute(email: String): String =
        "$AUTH_OTP_VERIFY/${java.net.URLEncoder.encode(email, Charsets.UTF_8.name())}"

    // Main bottom-tab routes.
    const val HOME = "home"
    const val MARKETPLACE = "marketplace"
    const val ORDERS = "orders"
    const val REPAIR = "repair"
    const val PROFILE = "profile"

    // Marketplace detail (sub-route within main graph).
    const val MARKETPLACE_DETAIL = "marketplace/detail"
    const val MARKETPLACE_DETAIL_ARG_ID = "partId"
    fun marketplaceDetailRoute(partId: String): String = "$MARKETPLACE_DETAIL/$partId"

    // Cart (sub-route, full-screen — bottom nav hidden).
    const val CART = "cart"

    // Checkout (sub-route, full-screen — bottom nav hidden).
    const val CHECKOUT = "checkout"

    // Order detail (sub-route, full-screen — bottom nav hidden).
    const val ORDER_DETAIL = "orders/detail"
    const val ORDER_DETAIL_ARG_ID = "orderId"
    fun orderDetailRoute(orderId: String): String = "$ORDER_DETAIL/$orderId"

    // Rate a delivered spare-part order (sub-route, full-screen). The orderId
    // is a path arg so the screen is restorable after process death / share.
    const val RATE_ORDER = "orders/rate"
    const val RATE_ORDER_ARG_ID = "orderId"
    fun rateOrderRoute(orderId: String): String = "$RATE_ORDER/$orderId"

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

    // About screen (version, licenses, links — sub-route entered from Profile).
    const val ABOUT = "profile/about"

    // Change password (sub-route entered from Profile — signed-in user changes their Supabase password).
    const val CHANGE_PASSWORD = "profile/change_password"

    // Change email (sub-route entered from Profile — Supabase sends confirmation link to new address).
    const val CHANGE_EMAIL = "profile/change_email"

    // Favorites (saved parts) — sub-route entered from Profile.
    const val FAVORITES = "profile/favorites"

    // Engineer-specific dashboards (full-screen sub-routes entered from Home).
    const val MY_BIDS = "engineer/my_bids"
    const val EARNINGS = "engineer/earnings"
    const val ACTIVE_WORK = "engineer/active_work"
    const val ENGINEER_PROFILE = "engineer/profile"

    // Supplier-specific dashboards (full-screen sub-routes entered from Home).
    const val MY_LISTINGS = "supplier/listings"
    const val STOCK_ALERTS = "supplier/stock_alerts"
    const val SUPPLIER_ORDERS = "supplier/orders"
    const val SUPPLIER_RFQS = "supplier/rfqs"
    const val SUPPLIER_ADD_LISTING = "supplier/listings/add"

    // Manufacturer-specific dashboards (full-screen sub-routes entered from Home).
    const val RFQS_ASSIGNED = "manufacturer/rfqs"
    const val LEAD_PIPELINE = "manufacturer/leads"
    const val ANALYTICS = "manufacturer/analytics"

    // Logistics partner dashboards (full-screen sub-routes entered from Home).
    const val PICKUP_QUEUE = "logistics/pickups"
    const val ACTIVE_DELIVERIES = "logistics/active"
    const val COMPLETED_TODAY = "logistics/completed"

    // Hospital-side sub-routes.
    const val REQUEST_SERVICE = "hospital/request_service"
    const val HOSPITAL_CREATE_RFQ = "hospital/create_rfq"
    const val HOSPITAL_ACTIVE_JOBS = "hospital/active_jobs"
    const val HOSPITAL_MY_RFQS = "hospital/my_rfqs"

    // Hospital RFQ detail (read-only view with received bids).
    const val HOSPITAL_RFQ_DETAIL = "hospital/rfq/detail"
    const val HOSPITAL_RFQ_DETAIL_ARG_ID = "rfqId"
    fun hospitalRfqDetailRoute(rfqId: String): String = "$HOSPITAL_RFQ_DETAIL/$rfqId"

    // AI-powered equipment scanner — capture a photo, identify the equipment, link to parts.
    const val SCAN_EQUIPMENT = "scan/equipment"

    // Notifications inbox (live feed of in-app notifications, realtime-backed).
    const val NOTIFICATIONS = "notifications"

    // First-run feature tour. Shown once per device install AFTER role pick,
    // before the user lands in MainNavGraph. Gated by `userPrefs.tourSeen`.
    const val TOUR = "onboarding/tour"

    // Notification settings (per-category push mute toggles, persisted to
    // DataStore). Split from the inbox so the two surfaces can evolve
    // independently — the inbox is read-side data; settings is local prefs.
    const val NOTIFICATION_SETTINGS = "notifications/settings"
}
