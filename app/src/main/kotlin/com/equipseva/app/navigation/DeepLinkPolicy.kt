package com.equipseva.app.navigation

/**
 * Allow-list for routes that arrive from OUTSIDE the running UI: a notification
 * tray tap ([DeepLinkRouter.EXTRA_ROUTE]), an App Link, or any third-party app
 * that fires an explicit Intent at the exported [com.equipseva.app.MainActivity].
 *
 * Why this exists (A3-01): the activity cannot tell its own FCM PendingIntent
 * from an intent crafted by another installed app, and an "origin" extra would
 * be trivially forged. Before this policy, `EXTRA_ROUTE` was navigated verbatim —
 * `adb shell am start … --es com.equipseva.app.deeplink.ROUTE founder/dashboard`
 * mounted founder UI for any signed-in user, and attacker-chosen query text was
 * rendered on `founder/integrity`. RLS still protected the data; the defect is
 * unauthenticated navigation and a social-engineering surface (steering a user
 * into payout / email / password screens from outside the app).
 *
 * Policy: only the fixed notification destinations and the App-Link route
 * classes, each with a strict id shape. Everything else — founder/*, root_*,
 * auth*, onboarding, security/*, profile sub-forms, query strings, encoded or
 * unknown segments — is denied. Deny is silent for the user (default landing)
 * and logged by the caller.
 *
 * This is a CLIENT allow-list, not authorization. Every allowed destination
 * keeps its server-side checks (RLS on jobs/chats/contracts, verified-only
 * engineer profile RPC, self-only KYC/profile rows).
 */
object DeepLinkPolicy {

    private val UUID = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    private val JOB_CODE = Regex("^RPR-\\d{1,8}$", RegexOption.IGNORE_CASE)

    /** Exact routes that carry no id and are legitimate notification landings. */
    private val EXACT = setOf(
        Routes.HOME,
        Routes.PROFILE,
        Routes.KYC,
        Routes.NOTIFICATIONS,
        Routes.ENGINEER_DIRECTORY,
        Routes.ENGINEER_AMC_VISITS,
    )

    /** Parameterised routes: prefix → validator for the single trailing segment. */
    private val PARAMETERISED: List<Pair<String, (String) -> Boolean>> = listOf(
        Routes.REPAIR_DETAIL to { id -> JOB_CODE.matches(id) || UUID.matches(id) },
        Routes.CHAT_DETAIL to { id -> UUID.matches(id) },
        Routes.ENGINEER_PUBLIC_PROFILE to { id -> UUID.matches(id) },
        Routes.AMC_CONTRACT_DETAIL to { id -> UUID.matches(id) },
    )

    /**
     * True when [route] may be opened from an external intent. Rejects blank,
     * whitespace, query/fragment characters, percent-encoding and anything not
     * in the two tables above.
     */
    fun isExternallyAllowed(route: String?): Boolean {
        if (route.isNullOrBlank()) return false
        if (route.any { it.isWhitespace() } || route.any { it in FORBIDDEN_CHARS }) return false
        if (route in EXACT) return true
        for ((prefix, valid) in PARAMETERISED) {
            val marker = "$prefix/"
            if (route.startsWith(marker)) {
                val id = route.removePrefix(marker)
                return id.isNotEmpty() && '/' !in id && valid(id)
            }
        }
        return false
    }

    /** Routes that must NEVER be reachable from outside the authenticated UI. */
    fun isPrivileged(route: String): Boolean =
        route.startsWith("founder/") || route.startsWith("root_") || route.startsWith("auth")

    private const val FORBIDDEN_CHARS = "?#%\\"
}
