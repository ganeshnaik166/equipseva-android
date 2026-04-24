package com.equipseva.app.features.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.push.NotificationChannels
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** UI model for one toggleable push category. */
data class PushCategoryToggle(
    val channelId: String,
    val label: String,
    val description: String,
    val muted: Boolean,
)

/**
 * Exposes the user's per-category push mute choices, backed by DataStore via
 * [UserPrefs.observeMutedPushCategories]. Toggling writes through
 * [UserPrefs.setMutedPushCategories] so the choice survives process death;
 * `EquipSevaMessagingService` reads the same flow to drop muted deliveries.
 */
@HiltViewModel
class NotificationSettingsViewModel @Inject constructor(
    private val userPrefs: UserPrefs,
) : ViewModel() {

    val categories: StateFlow<List<PushCategoryToggle>> = userPrefs
        .observeMutedPushCategories()
        .map { muted -> buildCategories(muted) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = buildCategories(emptySet()),
        )

    fun toggle(channelId: String) {
        viewModelScope.launch {
            val current = userPrefs.observeMutedPushCategories().first()
            val next = if (channelId in current) current - channelId else current + channelId
            userPrefs.setMutedPushCategories(next)
        }
    }

    private fun buildCategories(muted: Set<String>): List<PushCategoryToggle> = listOf(
        PushCategoryToggle(
            channelId = NotificationChannels.ORDERS,
            label = "Order updates",
            description = "Order status, delivery, returns",
            muted = NotificationChannels.ORDERS in muted,
        ),
        PushCategoryToggle(
            channelId = NotificationChannels.JOBS,
            label = "Available jobs",
            description = "New repair jobs and bid responses",
            muted = NotificationChannels.JOBS in muted,
        ),
        PushCategoryToggle(
            channelId = NotificationChannels.CHAT,
            label = "Chat messages",
            description = "Direct messages with hospitals and engineers",
            muted = NotificationChannels.CHAT in muted,
        ),
        PushCategoryToggle(
            channelId = NotificationChannels.ACCOUNT,
            label = "Account & security",
            description = "Verification, KYC, security alerts",
            muted = NotificationChannels.ACCOUNT in muted,
        ),
    )
}
