package com.equipseva.app.navigation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.prefs.UserPrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Owns the decision of whether a deep-link event should actually navigate.
 * The [DeepLinkRouter] produces raw events straight from the intent; this host
 * forwards them through the events SharedFlow to MainNavGraph.
 *
 * Marketplace order verification was stripped along with the marketplace
 * surface in the v1 cleanup. Today only push-notification kind→route events
 * flow through here; future cross-user verification (e.g. "engineer is allowed
 * to view this repair_job") can be added back as new branches in [init].
 */
@HiltViewModel
class DeepLinkHost @Inject constructor(
    router: DeepLinkRouter,
    userPrefs: UserPrefs,
) : ViewModel() {

    val activeRole: Flow<String?> = userPrefs.activeRole

    sealed interface VerifiedEvent {
        /**
         * Pre-resolved in-app route from a notification tap. Forwarded as-is
         * — the FCM service already mapped the (kind, data) payload, and a
         * malformed kind is filtered out before we ever see it here.
         */
        data class OpenRoute(val route: String) : VerifiedEvent
    }

    private val _events = MutableSharedFlow<VerifiedEvent>(
        replay = 0,
        extraBufferCapacity = 4,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val events: SharedFlow<VerifiedEvent> = _events.asSharedFlow()

    init {
        viewModelScope.launch {
            router.events.collect { raw ->
                when (raw) {
                    is DeepLinkRouter.Event.OpenRoute -> _events.tryEmit(VerifiedEvent.OpenRoute(raw.route))
                }
            }
        }
    }
}
