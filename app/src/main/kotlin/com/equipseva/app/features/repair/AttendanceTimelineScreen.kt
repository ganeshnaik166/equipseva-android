package com.equipseva.app.features.repair

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.repair.AttendanceRepository
import com.equipseva.app.core.location.LocationFetcher
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDateTime
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class AttendanceTimelineViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: AttendanceRepository,
    private val locationFetcher: LocationFetcher,
) : ViewModel() {
    private val jobId: String =
        checkNotNull(savedState.get<String>(Routes.ATTENDANCE_ARG_JOB_ID)) {
            "AttendanceTimelineViewModel requires arg ${Routes.ATTENDANCE_ARG_JOB_ID}"
        }

    /** r1443 — only the accepted engineer gets the check-in/out actions. */
    val isEngineer: Boolean = savedState.get<Boolean>(Routes.ATTENDANCE_ARG_IS_ENGINEER) ?: false

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<AttendanceRepository.Attendance> = emptyList(),
        // r1443 — check-in/out capture state.
        val capturing: Boolean = false,
        val actionError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetch(jobId)
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                // r1452 — keep a loaded timeline on a transient refresh failure.
                .onFailure { e ->
                    _state.update {
                        if (it.rows.isEmpty()) it.copy(loading = false, refreshing = false, error = e.toUserMessage())
                        else it.copy(loading = false, refreshing = false)
                    }
                }
        }
    }

    fun onPullToRefresh() = reload(initial = false)

    fun hasLocationPermission(): Boolean = locationFetcher.hasPermission()

    fun clearActionError() = _state.update { it.copy(actionError = null) }

    fun onLocationPermissionDenied() = _state.update {
        it.copy(actionError = "Location permission is needed to record an on-site check-in.")
    }

    /** The event the next tap should record, derived from the latest event. */
    fun nextEventKind(): String =
        nextAttendanceEvent(_state.value.rows.maxByOrNull { it.deviceCapturedAt ?: it.createdAt ?: "" }?.eventKind)

    /**
     * Capture the device location and record a check-in/out (r1443). Requires
     * location permission (the screen requests it first). On success reloads so
     * the new event lands on the timeline.
     */
    fun checkIn() {
        if (_state.value.capturing) return
        val eventKind = nextEventKind()
        _state.update { it.copy(capturing = true, actionError = null) }
        viewModelScope.launch {
            val coords = locationFetcher.currentCoords()
            if (coords == null) {
                _state.update {
                    it.copy(capturing = false, actionError = "Couldn't get your location. Turn on GPS/location and try again.")
                }
                return@launch
            }
            repo.record(jobId, eventKind, coords.lat, coords.lng)
                .onSuccess { _state.update { it.copy(capturing = false) }; reload() }
                .onFailure { e -> _state.update { it.copy(capturing = false, actionError = e.toUserMessage()) } }
        }
    }
}

/**
 * GPS attendance timeline (r1409): the engineer's arrival check-in / departure
 * check-out events for one repair job — device time, distance from the
 * hospital, and a suspicious-distance flag. Read-only; surfaces
 * attendance_for_job() (round 496). Reached from the job detail "Records".
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun AttendanceTimelineScreen(
    onBack: () -> Unit,
    viewModel: AttendanceTimelineViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    val permLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> if (granted) viewModel.checkIn() else viewModel.onLocationPermissionDenied() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Attendance", onBack = onBack)
            if (viewModel.isEngineer) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    val checkingIn = viewModel.nextEventKind() == "arrival_checkin"
                    EsBtn(
                        text = when {
                            state.capturing -> "Recording…"
                            checkingIn -> "Check in at site"
                            else -> "Check out"
                        },
                        onClick = {
                            viewModel.clearActionError()
                            if (viewModel.hasLocationPermission()) viewModel.checkIn()
                            else permLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                        },
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Lg,
                        full = true,
                        disabled = state.capturing,
                    )
                    state.actionError?.let {
                        Text(it, style = EsType.Caption, color = SevaDanger500)
                    }
                }
            }
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.LocationOn,
                        title = "Couldn't load attendance",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.LocationOn,
                        title = "No attendance yet",
                        subtitle = "When the engineer checks in on site and checks out, those GPS-stamped events appear here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.id }) { row -> AttendanceRow(row) }
                    }
                }
            }
        }
    }
}

@Composable
private fun AttendanceRow(row: AttendanceRepository.Attendance) {
    val (pillText, pillKind) = attendanceSuspiciousPill(row.suspiciousDistance)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                attendanceEventLabel(row.eventKind),
                style = EsType.Body.copy(fontWeight = FontWeight.Medium),
                color = SevaInk900,
            )
            val meta = listOfNotNull(
                row.deviceCapturedAt?.takeIf { it.isNotBlank() }?.let { prettyDateTime(it) },
                row.distanceFromHospitalM?.let { "${formatDistanceM(it)} from site" },
            ).joinToString(" · ")
            if (meta.isNotEmpty()) {
                Text(meta, style = EsType.Caption, color = SevaInk500)
            }
        }
        // Only show the on-site/far pill when the server actually measured the
        // distance. The in-app check-in/out path omits expected coords, so
        // distanceFromHospitalM is null and suspiciousDistance defaults to
        // false — a green "On-site" would then falsely assert verified presence
        // for an event where distance was never computed.
        if (row.distanceFromHospitalM != null) {
            Pill(text = pillText, kind = pillKind)
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Human label for an attendance event_kind (round 496); de-snake fallback. */
internal fun attendanceEventLabel(kind: String): String = when (kind) {
    "arrival_checkin" -> "Arrival check-in"
    "departure_checkout" -> "Departure check-out"
    else -> kind.replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/** Distance from the hospital: metres under 1 km, else km to one decimal; "—" when unknown. */
internal fun formatDistanceM(meters: Double?): String {
    if (meters == null) return "—"
    if (meters < 1000) return "${kotlin.math.round(meters).toLong()} m"
    val km = kotlin.math.round(meters / 100.0) / 10.0
    val s = if (km % 1.0 == 0.0) km.toLong().toString() else km.toString()
    return "$s km"
}

/** On-site vs far-from-site pill from the server's suspicious-distance flag. */
internal fun attendanceSuspiciousPill(suspicious: Boolean): Pair<String, PillKind> =
    if (suspicious) "Far from site" to PillKind.Danger else "On-site" to PillKind.Success

/**
 * The event the next check-in/out tap should record (r1443): after an arrival
 * check-in the next action is a departure check-out; otherwise (no events yet,
 * or the last event was a check-out) it's an arrival check-in.
 */
internal fun nextAttendanceEvent(latestEventKind: String?): String =
    if (latestEventKind == "arrival_checkin") "departure_checkout" else "arrival_checkin"
