package com.equipseva.app.navigation

/**
 * Routes admitted from outside the app's authenticated navigation UI.
 *
 * MainActivity is exported, so a notification PendingIntent's [DeepLinkRouter.EXTRA_ROUTE]
 * cannot be distinguished from the same extra supplied by another installed app. Keep this
 * allow-list smaller than the in-app route table. Server RLS and destination authorization
 * still decide whether the current account may read the referenced data.
 */
internal object DeepLinkPolicy {
    private val uuid = Regex(
        "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
        RegexOption.IGNORE_CASE,
    )
    private val jobCode = Regex("^RPR-\\d{1,8}$", RegexOption.IGNORE_CASE)

    private val fixedRoutes = setOf(
        Routes.HOME,
        Routes.PROFILE,
        Routes.KYC,
        Routes.NOTIFICATIONS,
        Routes.ENGINEER_DIRECTORY,
        Routes.ENGINEER_AMC_VISITS,
    )

    private val idRoutes: List<Pair<String, (String) -> Boolean>> = listOf(
        Routes.REPAIR_DETAIL to { id -> jobCode.matches(id) || uuid.matches(id) },
        Routes.CHAT_DETAIL to uuid::matches,
        Routes.ENGINEER_PUBLIC_PROFILE to uuid::matches,
        Routes.AMC_CONTRACT_DETAIL to uuid::matches,
    )

    fun allows(route: String?): Boolean {
        if (route.isNullOrBlank()) return false
        if (route.any { it.isWhitespace() || it in "?#%\\" }) return false
        if (route in fixedRoutes) return true
        return idRoutes.any { (prefix, validId) ->
            val marker = "$prefix/"
            route.startsWith(marker) && validId(route.removePrefix(marker))
        }
    }
}
