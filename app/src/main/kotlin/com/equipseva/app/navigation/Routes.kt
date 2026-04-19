package com.equipseva.app.navigation

object Routes {
    // Top-level graph IDs (sub-graphs wrapped under these names).
    const val AUTH_GRAPH = "auth_graph"
    const val MAIN_GRAPH = "main_graph"
    const val ROLE_SELECT = "role_select"

    // Auth sub-routes.
    const val AUTH_WELCOME = "auth/welcome"
    const val AUTH_SIGN_IN = "auth/sign_in"
    const val AUTH_SIGN_UP = "auth/sign_up"
    const val AUTH_OTP_REQUEST = "auth/otp_request"
    const val AUTH_OTP_VERIFY = "auth/otp_verify"

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
}
