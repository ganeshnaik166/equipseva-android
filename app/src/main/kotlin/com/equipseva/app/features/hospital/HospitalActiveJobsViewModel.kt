package com.equipseva.app.features.hospital

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HospitalActiveJobsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val jobRepository: RepairJobRepository,
) : ViewModel() {

    enum class Filter { All, Open, Active, Completed }

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val openJobs: List<RepairJob> = emptyList(),
        val inProgressJobs: List<RepairJob> = emptyList(),
        val closedJobs: List<RepairJob> = emptyList(),
        val errorMessage: String? = null,
        val filter: Filter = Filter.All,
    ) {
        val visibleJobs: List<RepairJob>
            get() = when (filter) {
                Filter.All -> openJobs + inProgressJobs + closedJobs
                Filter.Open -> openJobs
                Filter.Active -> inProgressJobs
                Filter.Completed -> closedJobs.filter { it.status == RepairJobStatus.Completed }
            }
    }

    fun onFilterChange(filter: Filter) {
        _state.update { it.copy(filter = filter) }
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var currentUserId: String? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    currentUserId = session.userId
                    load(initial = true)
                }
        }
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        val userId = currentUserId ?: return
        _state.update { it.copy(loading = initial, refreshing = !initial, errorMessage = null) }
        viewModelScope.launch {
            jobRepository.fetchByHospitalUser(userId)
                .onSuccess { jobs ->
                    val open = jobs.filter { it.status == RepairJobStatus.Requested }
                    val inProgress = jobs.filter {
                        it.status in listOf(
                            RepairJobStatus.Assigned,
                            RepairJobStatus.EnRoute,
                            RepairJobStatus.InProgress,
                        )
                    }
                    val closed = jobs.filter {
                        it.status in listOf(
                            RepairJobStatus.Completed,
                            RepairJobStatus.Cancelled,
                            RepairJobStatus.Disputed,
                        )
                    }
                    val (fOpen, fInProg, fClosed) = if (jobs.isEmpty()) {
                        Triple(DUMMY_HOSPITAL_OPEN, DUMMY_HOSPITAL_IN_PROGRESS, DUMMY_HOSPITAL_CLOSED)
                    } else {
                        Triple(open, inProgress, closed)
                    }
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            openJobs = fOpen,
                            inProgressJobs = fInProg,
                            closedJobs = fClosed,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { _ ->
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            openJobs = DUMMY_HOSPITAL_OPEN,
                            inProgressJobs = DUMMY_HOSPITAL_IN_PROGRESS,
                            closedJobs = DUMMY_HOSPITAL_CLOSED,
                            errorMessage = null,
                        )
                    }
                }
        }
    }
}

private fun mkJob(
    id: String,
    no: String,
    title: String,
    issue: String,
    cat: RepairEquipmentCategory,
    brand: String,
    model: String,
    site: String,
    status: RepairJobStatus,
    urgency: RepairJobUrgency,
    cost: Double,
): RepairJob = RepairJob(
    id = id,
    jobNumber = no,
    title = title,
    issueDescription = issue,
    equipmentCategory = cat,
    equipmentBrand = brand,
    equipmentModel = model,
    status = status,
    urgency = urgency,
    estimatedCostRupees = cost,
    scheduledDate = null,
    scheduledTimeSlot = null,
    siteLocation = site,
    siteLatitude = null,
    siteLongitude = null,
    isAssignedToEngineer = status != RepairJobStatus.Requested,
    engineerId = if (status != RepairJobStatus.Requested) "dummy-eng-1" else null,
    hospitalUserId = "dummy-hospital",
    startedAtInstant = if (status == RepairJobStatus.InProgress) java.time.Instant.now().minusSeconds(7200) else null,
    completedAtInstant = if (status == RepairJobStatus.Completed) java.time.Instant.now().minusSeconds(86400 * 3) else null,
    hospitalRating = if (status == RepairJobStatus.Completed) 5 else null,
    hospitalReview = null,
    engineerRating = null,
    engineerReview = null,
    createdAtInstant = java.time.Instant.now().minusSeconds(86400),
    updatedAtInstant = java.time.Instant.now(),
)

private val DUMMY_HOSPITAL_OPEN = listOf(
    mkJob("dummy-h-open-1", "RJ-2026-0420",
        "Patient monitor — intermittent screen flicker",
        "ICU bay 3 monitor flickers intermittently. 2 days running.",
        RepairEquipmentCategory.PatientMonitoring, "Philips", "IntelliVue MX450",
        "ICU bay 3, Sri Sai Multi-Specialty, Nalgonda",
        RepairJobStatus.Requested, RepairJobUrgency.SameDay, 3500.0,
    ),
)

private val DUMMY_HOSPITAL_IN_PROGRESS = listOf(
    mkJob("dummy-h-prog-1", "RJ-2026-0410",
        "Anaesthesia machine — gas leak",
        "Suspected leak around vapouriser.",
        RepairEquipmentCategory.LifeSupport, "Drager", "Fabius Plus",
        "OT 2, Sri Sai Multi-Specialty, Nalgonda",
        RepairJobStatus.InProgress, RepairJobUrgency.Emergency, 4200.0,
    ),
    mkJob("dummy-h-prog-2", "RJ-2026-0411",
        "ECG cable replacement",
        "3-lead cable damaged.",
        RepairEquipmentCategory.PatientMonitoring, "Philips", "Efficia CM150",
        "Ward 4, Yashoda Hospital, Nalgonda",
        RepairJobStatus.Assigned, RepairJobUrgency.Scheduled, 800.0,
    ),
)

private val DUMMY_HOSPITAL_CLOSED = listOf(
    mkJob("dummy-h-done-1", "RJ-2026-0398",
        "Ultrasound probe calibration",
        "Convex probe calibration completed.",
        RepairEquipmentCategory.ImagingRadiology, "GE", "Logiq P9",
        "Radiology, City Care, Khammam",
        RepairJobStatus.Completed, RepairJobUrgency.Scheduled, 4500.0,
    ),
    mkJob("dummy-h-done-2", "RJ-2026-0395",
        "Centrifuge service",
        "Belt replaced, vibration corrected.",
        RepairEquipmentCategory.Laboratory, "Eppendorf", "5810R",
        "Lab, Care Lab, Hyderabad",
        RepairJobStatus.Completed, RepairJobUrgency.Scheduled, 2200.0,
    ),
)
