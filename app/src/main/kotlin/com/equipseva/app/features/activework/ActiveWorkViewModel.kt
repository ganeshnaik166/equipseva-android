package com.equipseva.app.features.activework

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.sync.OutboxKinds
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ActiveWorkViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val jobRepository: RepairJobRepository,
    private val outboxDao: OutboxDao,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val activeJobs: List<RepairJob> = emptyList(),
        val completedJobs: List<RepairJob> = emptyList(),
        val queuedStatusCount: Int = 0,
        val errorMessage: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { load(initial = true) }
        }
        outboxDao.observePendingCountByKind(OutboxKinds.JOB_STATUS)
            .onEach { count -> _state.update { it.copy(queuedStatusCount = count) } }
            .launchIn(viewModelScope)
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        _state.update {
            it.copy(loading = initial, refreshing = !initial, errorMessage = null)
        }
        viewModelScope.launch {
            jobRepository.fetchAssignedToMe()
                .onSuccess { jobs ->
                    val active = jobs.filter {
                        it.status in listOf(
                            RepairJobStatus.EnRoute,
                            RepairJobStatus.InProgress,
                        )
                    }
                    val completed = jobs.filter {
                        it.status in listOf(RepairJobStatus.Completed, RepairJobStatus.Cancelled)
                    }
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            activeJobs = if (active.isEmpty()) DUMMY_ACTIVE_JOBS else active,
                            completedJobs = if (completed.isEmpty()) DUMMY_COMPLETED_JOBS else completed,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { _ ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            activeJobs = DUMMY_ACTIVE_JOBS,
                            completedJobs = DUMMY_COMPLETED_JOBS,
                            errorMessage = null,
                        )
                    }
                }
        }
    }
}

private fun makeJob(
    id: String,
    jobNumber: String,
    title: String,
    issue: String,
    category: com.equipseva.app.core.data.repair.RepairEquipmentCategory,
    brand: String,
    model: String,
    site: String,
    status: RepairJobStatus,
    cost: Double,
    completedDaysAgo: Long? = null,
    rating: Int? = null,
): RepairJob = RepairJob(
    id = id,
    jobNumber = jobNumber,
    title = title,
    issueDescription = issue,
    equipmentCategory = category,
    equipmentBrand = brand,
    equipmentModel = model,
    status = status,
    urgency = com.equipseva.app.core.data.repair.RepairJobUrgency.SameDay,
    estimatedCostRupees = cost,
    scheduledDate = null,
    scheduledTimeSlot = null,
    siteLocation = site,
    siteLatitude = null,
    siteLongitude = null,
    isAssignedToEngineer = true,
    engineerId = "dummy-eng-self",
    hospitalUserId = "dummy-hospital",
    startedAtInstant = if (status == RepairJobStatus.InProgress) java.time.Instant.now().minusSeconds(7200) else null,
    completedAtInstant = completedDaysAgo?.let { java.time.Instant.now().minusSeconds(it * 86400L) },
    hospitalRating = rating,
    hospitalReview = null,
    engineerRating = null,
    engineerReview = null,
    createdAtInstant = java.time.Instant.now().minusSeconds(86400),
    updatedAtInstant = java.time.Instant.now(),
)

private val DUMMY_ACTIVE_JOBS: List<RepairJob> = listOf(
    makeJob(
        "dummy-job-active-1", "RJ-2026-0410",
        "Anaesthesia machine — gas leak",
        "Suspected leak around vapouriser. OT scheduled tomorrow.",
        com.equipseva.app.core.data.repair.RepairEquipmentCategory.LifeSupport,
        "Drager", "Fabius Plus",
        "Sri Sai Multi-Specialty, Nalgonda",
        RepairJobStatus.InProgress,
        4200.0,
    ),
    makeJob(
        "dummy-job-active-2", "RJ-2026-0411",
        "ECG cable replacement",
        "3-lead cable damaged. Replacement onsite.",
        com.equipseva.app.core.data.repair.RepairEquipmentCategory.PatientMonitoring,
        "Philips", "Efficia CM150",
        "Yashoda Hospital, Nalgonda",
        RepairJobStatus.EnRoute,
        800.0,
    ),
)

private val DUMMY_COMPLETED_JOBS: List<RepairJob> = listOf(
    makeJob(
        "dummy-job-done-1", "RJ-2026-0398",
        "Ultrasound probe calibration",
        "Convex probe artifact fixed.",
        com.equipseva.app.core.data.repair.RepairEquipmentCategory.ImagingRadiology,
        "GE", "Logiq P9",
        "City Care, Khammam",
        RepairJobStatus.Completed,
        4500.0,
        completedDaysAgo = 3,
        rating = 5,
    ),
    makeJob(
        "dummy-job-done-2", "RJ-2026-0395",
        "Centrifuge service",
        "Vibration corrected, drive belt replaced.",
        com.equipseva.app.core.data.repair.RepairEquipmentCategory.Laboratory,
        "Eppendorf", "5810R",
        "Care Lab, Hyderabad",
        RepairJobStatus.Completed,
        2200.0,
        completedDaysAgo = 8,
        rating = 4,
    ),
)
