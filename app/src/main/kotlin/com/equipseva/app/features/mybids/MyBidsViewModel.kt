package com.equipseva.app.features.mybids

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
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
class MyBidsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val bidRepository: RepairBidRepository,
    private val jobRepository: RepairJobRepository,
    private val outboxDao: OutboxDao,
) : ViewModel() {

    data class MyBidRow(val bid: RepairBid, val job: RepairJob?)

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rows: List<MyBidRow> = emptyList(),
        val statusFilter: RepairBidStatus? = null,
        val queuedBidCount: Int = 0,
        val errorMessage: String? = null,
    ) {
        val visibleRows: List<MyBidRow>
            get() = if (statusFilter == null) rows
            else rows.filter { it.bid.status == statusFilter }
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun onStatusFilterChange(filter: RepairBidStatus?) {
        _state.update { it.copy(statusFilter = filter) }
    }

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { load(initial = true) }
        }
        outboxDao.observePendingCountByKind(OutboxKinds.REPAIR_BID)
            .onEach { count -> _state.update { it.copy(queuedBidCount = count) } }
            .launchIn(viewModelScope)
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        _state.update {
            it.copy(
                loading = initial,
                refreshing = !initial,
                errorMessage = null,
            )
        }
        viewModelScope.launch {
            bidRepository.fetchMyBids()
                .onSuccess { bids ->
                    val jobIds = bids.map { it.repairJobId }.toSet()
                    val jobsById = if (jobIds.isEmpty()) emptyMap()
                    else jobRepository.fetchByIds(jobIds)
                        .getOrElse { emptyList() }
                        .associateBy { it.id }
                    val realRows = bids.map { bid -> MyBidRow(bid, jobsById[bid.repairJobId]) }
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            rows = if (realRows.isEmpty()) DUMMY_BID_ROWS else realRows,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { _ ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            rows = DUMMY_BID_ROWS,
                            errorMessage = null,
                        )
                    }
                }
        }
    }
}

private fun makeDummyBid(
    id: String,
    jobId: String,
    amount: Double,
    eta: Int,
    status: RepairBidStatus,
    note: String,
): RepairBid = RepairBid(
    id = id,
    repairJobId = jobId,
    engineerUserId = "dummy-eng-self",
    amountRupees = amount,
    etaHours = eta,
    note = note,
    status = status,
    createdAtInstant = java.time.Instant.now().minusSeconds(3600),
    updatedAtInstant = java.time.Instant.now().minusSeconds(3600),
)

private fun makeDummyJob(
    id: String,
    jobNumber: String,
    title: String,
    issue: String,
    category: RepairEquipmentCategory,
    brand: String?,
    model: String?,
    site: String?,
    status: RepairJobStatus = RepairJobStatus.Requested,
): RepairJob = RepairJob(
    id = id,
    jobNumber = jobNumber,
    title = title,
    issueDescription = issue,
    equipmentCategory = category,
    equipmentBrand = brand,
    equipmentModel = model,
    status = status,
    urgency = RepairJobUrgency.SameDay,
    estimatedCostRupees = null,
    scheduledDate = null,
    scheduledTimeSlot = null,
    siteLocation = site,
    siteLatitude = null,
    siteLongitude = null,
    isAssignedToEngineer = false,
    engineerId = null,
    hospitalUserId = "dummy-hospital",
    startedAtInstant = null,
    completedAtInstant = null,
    hospitalRating = null,
    hospitalReview = null,
    engineerRating = null,
    engineerReview = null,
    createdAtInstant = java.time.Instant.now(),
    updatedAtInstant = java.time.Instant.now(),
)

private val DUMMY_BID_ROWS: List<MyBidsViewModel.MyBidRow> = listOf(
    MyBidsViewModel.MyBidRow(
        bid = makeDummyBid("dummy-bid-1", "dummy-job-1", 3200.0, 4, RepairBidStatus.Pending, "Can be onsite within 2 hours."),
        job = makeDummyJob(
            "dummy-job-1", "RJ-2026-0418",
            "ICU patient monitor flickering",
            "Patient monitor screen flicker, intermittent.",
            RepairEquipmentCategory.PatientMonitoring,
            "Philips", "IntelliVue MX450",
            "Sri Sai Multi-Specialty, Nalgonda",
        ),
    ),
    MyBidsViewModel.MyBidRow(
        bid = makeDummyBid("dummy-bid-2", "dummy-job-3", 2200.0, 8, RepairBidStatus.Accepted, "Battery replacement included."),
        job = makeDummyJob(
            "dummy-job-3", "RJ-2026-0421",
            "Defibrillator battery not holding charge",
            "Battery drains within 30 min.",
            RepairEquipmentCategory.PatientMonitoring,
            "Zoll", "R Series",
            "Yashoda Hospital, Nalgonda",
            status = RepairJobStatus.Assigned,
        ),
    ),
    MyBidsViewModel.MyBidRow(
        bid = makeDummyBid("dummy-bid-3", "dummy-job-old", 1800.0, 2, RepairBidStatus.Withdrawn, "Withdrawn — equipment moved."),
        job = makeDummyJob(
            "dummy-job-old", "RJ-2026-0405",
            "Centrifuge unbalanced",
            "Lab centrifuge vibrates excessively.",
            RepairEquipmentCategory.Laboratory,
            "Eppendorf", "5810R",
            "Care Lab, Hyderabad",
        ),
    ),
)
