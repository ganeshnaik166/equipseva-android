package com.equipseva.app.features.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.prefs.QuietHoursPrefs
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.features.auth.UserRole
import com.equipseva.app.core.push.NotificationChannels
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
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

    val categories: StateFlow<List<PushCategoryToggle>> = combine(
        userPrefs.observeMutedPushCategories(),
        userPrefs.activeRole,
    ) { muted, roleKey ->
        buildCategories(muted, UserRole.fromKey(roleKey))
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = buildCategories(emptySet(), null),
    )

    val quietHours: StateFlow<QuietHoursPrefs> = userPrefs
        .observeQuietHours()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = QuietHoursPrefs(enabled = false, startMinutes = 22 * 60, endMinutes = 7 * 60),
        )

    fun toggle(channelId: String) {
        viewModelScope.launch {
            val current = userPrefs.observeMutedPushCategories().first()
            val next = if (channelId in current) current - channelId else current + channelId
            userPrefs.setMutedPushCategories(next)
        }
    }

    fun setQuietHoursEnabled(on: Boolean) {
        viewModelScope.launch { userPrefs.setQuietHoursEnabled(on) }
    }

    fun setQuietHoursWindow(startMin: Int, endMin: Int) {
        viewModelScope.launch { userPrefs.setQuietHoursWindow(startMin, endMin) }
    }

    // "Order updates" deliberately omitted — v1 has no orders / cart /
    // checkout (marketplace deferred to v2 per project_v1_monetization_free.md).
    // Showing the toggle would let users mute a category that never fires.
    private fun buildCategories(
        muted: Set<String>,
        role: UserRole?,
    ): List<PushCategoryToggle> {
        // Hospital users don't bid on jobs — they post bookings and watch
        // engineers respond. Same FCM channel, different reading frame.
        val (jobsLabel, jobsDescription) = if (role == UserRole.HOSPITAL) {
            "Booking updates" to "Bids received, engineer assigned, dispute updates"
        } else {
            "Available jobs" to "New repair jobs and bid responses"
        }
        return listOf(
            PushCategoryToggle(
                channelId = NotificationChannels.JOBS,
                label = jobsLabel,
                description = jobsDescription,
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
}
