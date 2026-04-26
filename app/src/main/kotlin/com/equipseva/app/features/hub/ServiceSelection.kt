package com.equipseva.app.features.hub

import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Carries the user's Hub pick across the auth boundary so post-auth code can
 * grant the matching role (when needed) and land them on the right screen.
 * Process-local — if the process dies during auth the user lands on Hub
 * again on next cold-start, which is fine.
 */
object ServiceSelection {
    /**
     * @param roleKey one of the user_role storage keys, or null for a
     *   role-less landing (e.g. the founder Admin tile).
     * @param landingRoute the route inside MainNavGraph to navigate to once
     *   we land on Main; null means the default home tab.
     */
    data class Selection(
        val roleKey: String?,
        val landingRoute: String?,
    )

    val selected = MutableStateFlow<Selection?>(null)

    fun set(value: Selection?) {
        selected.value = value
    }

    fun consume(): Selection? {
        val value = selected.value
        selected.value = null
        return value
    }
}
