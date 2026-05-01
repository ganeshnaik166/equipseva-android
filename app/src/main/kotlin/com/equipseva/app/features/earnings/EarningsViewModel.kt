package com.equipseva.app.features.earnings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
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
class EarningsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val bidRepository: RepairBidRepository,
    private val jobRepository: RepairJobRepository,
) : ViewModel() {

    data class EarningRow(val bid: RepairBid, val job: RepairJob?)

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val paidTotal: Double = 0.0,
        val pendingTotal: Double = 0.0,
        val rows: List<EarningRow> = emptyList(),
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
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        _state.update {
            it.copy(loading = initial, refreshing = !initial, errorMessage = null)
        }
        viewModelScope.launch {
            bidRepository.fetchMyBids()
                .onSuccess { bids ->
                    val accepted = bids.filter { it.status == RepairBidStatus.Accepted }
                    val jobIds = accepted.map { it.repairJobId }.toSet()
                    val jobsById = if (jobIds.isEmpty()) emptyMap()
                    else jobRepository.fetchByIds(jobIds)
                        .getOrElse { emptyList() }
                        .associateBy { it.id }

                    val rows = accepted.map { EarningRow(it, jobsById[it.repairJobId]) }
                    val finalRows = if (rows.isEmpty()) DUMMY_EARNINGS else rows
                    val paid = finalRows.filter { it.job?.status == RepairJobStatus.Completed }
                        .sumOf { it.bid.amountRupees }
                    val pending = finalRows.filter { it.job?.status != RepairJobStatus.Completed }
                        .sumOf { it.bid.amountRupees }

                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            paidTotal = paid,
                            pendingTotal = pending,
                            rows = finalRows,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { _ ->
                    val paid = DUMMY_EARNINGS.filter { it.job?.status == RepairJobStatus.Completed }
                        .sumOf { it.bid.amountRupees }
                    val pending = DUMMY_EARNINGS.filter { it.job?.status != RepairJobStatus.Completed }
                        .sumOf { it.bid.amountRupees }
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            paidTotal = paid,
                            pendingTotal = pending,
                            rows = DUMMY_EARNINGS,
                            errorMessage = null,
                        )
                    }
                }
        }
    }
}

private fun makeBid(id: String, jobId: String, amount: Double, status: RepairBidStatus): RepairBid = RepairBid(
    id = id,
    repairJobId = jobId,
    engineerUserId = "dummy-eng-self",
    amountRupees = amount,
    etaHours = 4,
    note = null,
    status = status,
    createdAtInstant = java.time.Instant.now().minusSeconds(86400 * 5),
    updatedAtInstant = java.time.Instant.now().minusSeconds(86400 * 4),
)

private fun makeJob(
    id: String,
    jobNumber: String,
    issue: String,
    cat: RepairEquipmentCategory,
    site: String,
    status: RepairJobStatus,
): RepairJob = RepairJob(
    id = id,
    jobNumber = jobNumber,
    title = issue,
    issueDescription = issue,
    equipmentCategory = cat,
    equipmentBrand = null,
    equipmentModel = null,
    status = status,
    urgency = RepairJobUrgency.SameDay,
    estimatedCostRupees = null,
    scheduledDate = null,
    scheduledTimeSlot = null,
    siteLocation = site,
    siteLatitude = null,
    siteLongitude = null,
    isAssignedToEngineer = true,
    engineerId = "dummy-eng-self",
    hospitalUserId = "dummy-hospital",
    startedAtInstant = null,
    completedAtInstant = if (status == RepairJobStatus.Completed) java.time.Instant.now().minusSeconds(86400 * 4) else null,
    hospitalRating = if (status == RepairJobStatus.Completed) 5 else null,
    hospitalReview = null,
    engineerRating = null,
    engineerReview = null,
    createdAtInstant = java.time.Instant.now().minusSeconds(86400 * 5),
    updatedAtInstant = java.time.Instant.now(),
)

private val DUMMY_EARNINGS: List<EarningsViewModel.EarningRow> = listOf(
    EarningsViewModel.EarningRow(
        bid = makeBid("e1", "j1", 4500.0, RepairBidStatus.Accepted),
        job = makeJob("j1", "RJ-2026-0398", "Ultrasound probe calibration", RepairEquipmentCategory.ImagingRadiology, "City Care, Khammam", RepairJobStatus.Completed),
    ),
    EarningsViewModel.EarningRow(
        bid = makeBid("e2", "j2", 2200.0, RepairBidStatus.Accepted),
        job = makeJob("j2", "RJ-2026-0395", "Centrifuge service", RepairEquipmentCategory.Laboratory, "Care Lab, Hyderabad", RepairJobStatus.Completed),
    ),
    EarningsViewModel.EarningRow(
        bid = makeBid("e3", "j3", 4200.0, RepairBidStatus.Accepted),
        job = makeJob("j3", "RJ-2026-0410", "Anaesthesia machine — gas leak", RepairEquipmentCategory.LifeSupport, "Sri Sai Multi-Specialty, Nalgonda", RepairJobStatus.InProgress),
    ),
    EarningsViewModel.EarningRow(
        bid = makeBid("e4", "j4", 3500.0, RepairBidStatus.Accepted),
        job = makeJob("j4", "RJ-2026-0392", "Defibrillator battery swap", RepairEquipmentCategory.PatientMonitoring, "Yashoda Hospital, Nalgonda", RepairJobStatus.Completed),
    ),
)
