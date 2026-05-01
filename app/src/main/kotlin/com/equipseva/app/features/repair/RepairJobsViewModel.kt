package com.equipseva.app.features.repair

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.repair.state.RepairJobsUiState
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val PAGE_SIZE = 20
private const val SEARCH_DEBOUNCE_MS = 300L

@OptIn(FlowPreview::class)
@HiltViewModel
class RepairJobsViewModel @Inject constructor(
    private val repository: RepairJobRepository,
    private val bidRepository: RepairBidRepository,
    private val engineerRepository: EngineerRepository,
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(RepairJobsUiState())
    val state: StateFlow<RepairJobsUiState> = _state.asStateFlow()

    /** Tracks the in-flight query/page combo so stale results get dropped. */
    private var pageJob: Job? = null

    init {
        refresh()
        loadEngineerBase()

        // Re-query when the typed query stabilises. Drop(1) skips the initial
        // empty-query emission which `refresh()` in init already handled.
        _state
            .map { it.query }
            .distinctUntilChanged()
            .drop(1)
            .debounce(SEARCH_DEBOUNCE_MS)
            .onEach { refresh() }
            .launchIn(viewModelScope)
    }

    /**
     * Pulls the engineer's registered base coords once at startup so the
     * map widget can centre on them and draw the radius circle. Gracefully
     * leaves baseLatitude/Longitude null when the engineer hasn't completed
     * KYC + location capture yet.
     */
    private fun loadEngineerBase() {
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull() ?: return@launch
            val engineer = engineerRepository.fetchByUserId(session.userId).getOrNull() ?: return@launch
            _state.update {
                it.copy(
                    baseLatitude = engineer.latitude,
                    baseLongitude = engineer.longitude,
                )
            }
        }
    }

    fun onQueryChange(value: String) {
        _state.update { it.copy(query = value, errorMessage = null) }
    }

    /**
     * Pick a new radius (or `null` for "All distances"). Triggers a fresh
     * load through the proximity RPC when set, or the unfiltered list when
     * null. Re-using `refresh()` keeps loading-state semantics consistent
     * with the search-debounce path.
     */
    fun onRadiusChange(radiusKm: Int?) {
        if (_state.value.radiusKm == radiusKm) return
        _state.update { it.copy(radiusKm = radiusKm) }
        refresh()
    }

    fun onRefresh() = refresh(viaPullToRefresh = true)

    fun onReachEnd() {
        val current = _state.value
        if (current.loadingMore || current.refreshing || current.initialLoading || current.endReached) return
        loadNext(page = current.items.size / PAGE_SIZE)
    }

    private fun refresh(viaPullToRefresh: Boolean = false) {
        pageJob?.cancel()
        _state.update {
            it.copy(
                initialLoading = it.items.isEmpty() && !viaPullToRefresh,
                refreshing = viaPullToRefresh,
                endReached = false,
                errorMessage = null,
                mineLoading = it.mineItems.isEmpty() && !viaPullToRefresh,
                mineErrorMessage = null,
            )
        }
        pageJob = viewModelScope.launch {
            val current = _state.value
            val radius = current.radiusKm
            val bidsDeferred = async { bidRepository.fetchMyBids() }
            val mineDeferred = async { repository.fetchAssignedToMe() }
            // When a radius is set, prefer the proximity RPC which filters
            // server-side and returns distance per row. The text query isn't
            // wired into the RPC yet — fall back to unfiltered list when the
            // user is searching, since the radius+text combo would need a
            // bigger function signature than today's MVP justifies.
            val useProximity = radius != null && current.query.isBlank()
            if (useProximity) {
                val proximityDeferred = async {
                    repository.fetchNearbyJobs(radiusKm = radius!!.toDouble())
                }
                proximityDeferred.await().fold(
                    onSuccess = { rows ->
                        val ownBids = bidsDeferred.await().getOrNull().orEmpty()
                            .associateBy { it.repairJobId }
                        _state.update {
                            it.copy(
                                items = rows.map { row -> row.job },
                                distanceByJobId = rows.associate { row ->
                                    row.job.id to row.distanceKm
                                },
                                coordsByJobId = rows
                                    .mapNotNull { row ->
                                        val lat = row.hospitalLatitude ?: return@mapNotNull null
                                        val lng = row.hospitalLongitude ?: return@mapNotNull null
                                        row.job.id to (lat to lng)
                                    }
                                    .toMap(),
                                ownBidsByJob = ownBids,
                                initialLoading = false,
                                refreshing = false,
                                // RPC is single-shot (no paging today); mark
                                // endReached so the infinite-scroll path
                                // doesn't try to load page 2.
                                endReached = true,
                            )
                        }
                    },
                    onFailure = { ex ->
                        _state.update {
                            it.copy(
                                initialLoading = false,
                                refreshing = false,
                                errorMessage = ex.toUserMessage(),
                            )
                        }
                    },
                )
            } else {
                val jobsDeferred = async {
                    repository.fetchOpenJobs(page = 0, pageSize = PAGE_SIZE, query = current.query)
                }
                jobsDeferred.await().fold(
                    onSuccess = { rows ->
                        val ownBids = bidsDeferred.await().getOrNull().orEmpty()
                            .associateBy { it.repairJobId }
                        val finalRows = if (rows.isEmpty()) DUMMY_OPEN_JOBS else rows
                        _state.update {
                            it.copy(
                                items = finalRows,
                                distanceByJobId = if (rows.isEmpty()) DUMMY_DISTANCES else emptyMap(),
                                coordsByJobId = emptyMap(),
                                ownBidsByJob = ownBids,
                                initialLoading = false,
                                refreshing = false,
                                endReached = finalRows.size < PAGE_SIZE,
                            )
                        }
                    },
                    onFailure = { _ ->
                        _state.update {
                            it.copy(
                                items = DUMMY_OPEN_JOBS,
                                distanceByJobId = DUMMY_DISTANCES,
                                initialLoading = false,
                                refreshing = false,
                                errorMessage = null,
                                endReached = true,
                            )
                        }
                    },
                )
            }
            mineDeferred.await().fold(
                onSuccess = { rows ->
                    val finalMine = if (rows.isEmpty()) DUMMY_ASSIGNED_JOBS else rows
                    _state.update {
                        it.copy(mineItems = finalMine, mineLoading = false, mineErrorMessage = null)
                    }
                },
                onFailure = { _ ->
                    _state.update {
                        it.copy(mineItems = DUMMY_ASSIGNED_JOBS, mineLoading = false, mineErrorMessage = null)
                    }
                },
            )
        }
    }

    private fun loadNext(page: Int) {
        pageJob?.cancel()
        _state.update { it.copy(loadingMore = true, errorMessage = null) }
        pageJob = viewModelScope.launch {
            val current = _state.value
            repository.fetchOpenJobs(
                page = page,
                pageSize = PAGE_SIZE,
                query = current.query,
            ).fold(
                onSuccess = { rows ->
                    _state.update {
                        it.copy(
                            items = it.items + rows,
                            loadingMore = false,
                            endReached = rows.size < PAGE_SIZE,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(
                            loadingMore = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
        }
    }
}

private fun dummyJob(
    id: String,
    jobNumber: String,
    title: String,
    issue: String,
    category: RepairEquipmentCategory,
    brand: String?,
    model: String?,
    urgency: RepairJobUrgency,
    cost: Double?,
    site: String?,
    status: RepairJobStatus = RepairJobStatus.Requested,
    isAssigned: Boolean = false,
): RepairJob = RepairJob(
    id = id,
    jobNumber = jobNumber,
    title = title,
    issueDescription = issue,
    equipmentCategory = category,
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
    isAssignedToEngineer = isAssigned,
    engineerId = if (isAssigned) "dummy-eng-self" else null,
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

internal val DUMMY_OPEN_JOBS: List<RepairJob> = listOf(
    dummyJob(
        id = "dummy-job-1",
        jobNumber = "RJ-2026-0418",
        title = "ICU patient monitor flickering",
        issue = "Patient monitor in ICU bay 3 shows intermittent screen flicker. Goes blank for ~5s every few minutes.",
        category = RepairEquipmentCategory.PatientMonitoring,
        brand = "Philips",
        model = "IntelliVue MX450",
        urgency = RepairJobUrgency.SameDay,
        cost = 3500.0,
        site = "Sri Sai Multi-Specialty, Nalgonda",
    ),
    dummyJob(
        id = "dummy-job-2",
        jobNumber = "RJ-2026-0419",
        title = "Ventilator low-pressure alarm",
        issue = "Ventilator triggers low-pressure alarm intermittently during PEEP cycle. Need urgent diagnostic.",
        category = RepairEquipmentCategory.LifeSupport,
        brand = "Drager",
        model = "Evita V300",
        urgency = RepairJobUrgency.Emergency,
        cost = 5000.0,
        site = "Apollo Specialty, Suryapet",
    ),
    dummyJob(
        id = "dummy-job-3",
        jobNumber = "RJ-2026-0421",
        title = "Defibrillator battery not holding charge",
        issue = "Battery drains within 30 min of full charge. Used in OT — need within 2 days.",
        category = RepairEquipmentCategory.PatientMonitoring,
        brand = "Zoll",
        model = "R Series",
        urgency = RepairJobUrgency.Scheduled,
        cost = 2500.0,
        site = "Yashoda Hospital, Nalgonda",
    ),
    dummyJob(
        id = "dummy-job-4",
        jobNumber = "RJ-2026-0422",
        title = "Ultrasound probe calibration",
        issue = "Convex probe showing artifacts. Need calibration + possibly replacement.",
        category = RepairEquipmentCategory.ImagingRadiology,
        brand = "GE",
        model = "Logiq P9",
        urgency = RepairJobUrgency.Scheduled,
        cost = 4500.0,
        site = "City Care, Khammam",
    ),
)

internal val DUMMY_DISTANCES: Map<String, Double> = mapOf(
    "dummy-job-1" to 2.4,
    "dummy-job-2" to 18.7,
    "dummy-job-3" to 4.1,
    "dummy-job-4" to 65.3,
)

internal val DUMMY_ASSIGNED_JOBS: List<RepairJob> = listOf(
    dummyJob(
        id = "dummy-job-active-1",
        jobNumber = "RJ-2026-0410",
        title = "Anaesthesia machine — gas leak diagnostic",
        issue = "Suspected leak around vapouriser seat. OT scheduled tomorrow.",
        category = RepairEquipmentCategory.LifeSupport,
        brand = "Drager",
        model = "Fabius Plus",
        urgency = RepairJobUrgency.SameDay,
        cost = 4200.0,
        site = "Sri Sai Multi-Specialty, Nalgonda",
        status = RepairJobStatus.InProgress,
        isAssigned = true,
    ),
    dummyJob(
        id = "dummy-job-active-2",
        jobNumber = "RJ-2026-0411",
        title = "ECG cable replacement",
        issue = "3-lead ECG cable damaged. Bringing replacement.",
        category = RepairEquipmentCategory.PatientMonitoring,
        brand = "Philips",
        model = "Efficia CM150",
        urgency = RepairJobUrgency.Scheduled,
        cost = 800.0,
        site = "Yashoda Hospital, Nalgonda",
        status = RepairJobStatus.Assigned,
        isAssigned = true,
    ),
)
