package com.equipseva.app.features.hub

import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Carries the user's hub selection across the auth boundary so post-auth
 * code can grant the matching role and land them on Main with the right
 * activeRole. Process-local — if the process dies during auth the user
 * lands on Hub again on next cold-start, which is fine.
 */
object ServiceSelection {
    /** Storage key of the persona the user picked on the Hub, or null. */
    val selected = MutableStateFlow<String?>(null)

    fun set(roleKey: String?) {
        selected.value = roleKey
    }

    fun consume(): String? {
        val value = selected.value
        selected.value = null
        return value
    }
}
