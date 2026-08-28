package com.equipseva.app.features.repair

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.analytics.AnalyticsClient
import com.equipseva.app.core.data.analytics.AnalyticsEvent
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
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
    private val analytics: AnalyticsClient,
) : ViewModel() {

    private val _state = MutableStateFlow(RepairJobsUiState())
    val state: StateFlow<RepairJobsUiState> = _state.asStateFlow()

    /** Tracks the in-flight query/page combo so stale results get dropped. */
    private var pageJob: Job? = null

    init {
        // r516 (v0.4 P5 #10) — funnel ping when engineer/hospital opens job feed.
        analytics.track(AnalyticsEvent.JOB_FEED_VIEWED)
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
            // r1497 — fetch SUCCESS marks baseLoaded even when the engineer
            // row (or its coords) is absent: that's exactly the "no service
            // location set" case the nearby pre-empt needs to trust. A fetch
            // FAILURE leaves baseLoaded false so a network blip never
            // mislabels a configured engineer as location-less.
            val fetched = engineerRepository.fetchByUserId(session.userId).getOrNull() ?: return@launch
            _state.update {
                it.copy(
                    baseLatitude = fetched.latitude,
                    baseLongitude = fetched.longitude,
                    baseLoaded = true,
                )
            }
            // The init refresh() raced ahead of this fetch. If it went to the
            // proximity RPC without a base, it surfaced the misleading
            // generic error — re-run now that the pre-empt can take over.
            if (shouldPreemptNearbyFetch(
                    radiusKm = _state.value.radiusKm,
                    queryIsBlank = _state.value.query.isBlank(),
                    baseLoaded = true,
                    baseLatitude = fetched.latitude,
                    baseLongitude = fetched.longitude,
                )
            ) {
                refresh()
            }
        }
    }

    fun onQueryChange(value: String) {
        // Round 422 — cap at 100 chars; search is a job-title / number /
        // hospital-name match. No legit query exceeds this length.
        _state.update { it.copy(query = value.take(100), errorMessage = null) }
    }

    /**
     * Pick a new radius (or `null` for "All distances"). Triggers a fresh
     * load through the proximity RPC when set, or the unfiltered list when
     * null. Re-using `refresh()` keeps loading-state semantics consistent
     * with the search-debounce path.
     */
    fun onRadiusChange(radiusKm: Int?) {
        if (_state.value.radiusKm == radiusKm) return
        // Mirror onQueryChange: clear any stale errorMessage so the
        // user doesn't see "Couldn't load" sticking around while the
        // new radius query is in flight.
        _state.update { it.copy(radiusKm = radiusKm, errorMessage = null) }
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
            )
        }
        pageJob = viewModelScope.launch {
            val current = _state.value
            val radius = current.radiusKm
            // r1497 — an engineer with NO service location can't use the
            // proximity RPC (it fails server-side with a generic 42501 whose
            // copy misleadingly blames KYC). Once the engineer row is loaded
            // and confirms the base is missing, skip the doomed call and show
            // the actionable message instead. The map's "Set service
            // location" chip and the All filter both remain available.
            if (shouldPreemptNearbyFetch(
                    radiusKm = radius,
                    queryIsBlank = current.query.isBlank(),
                    baseLoaded = current.baseLoaded,
                    baseLatitude = current.baseLatitude,
                    baseLongitude = current.baseLongitude,
                )
            ) {
                _state.update {
                    it.copy(
                        items = emptyList(),
                        distanceByJobId = emptyMap(),
                        coordsByJobId = emptyMap(),
                        initialLoading = false,
                        refreshing = false,
                        endReached = true,
                        errorMessage = MISSING_SERVICE_LOCATION_MESSAGE,
                    )
                }
                return@launch
            }
            val bidsDeferred = async { bidRepository.fetchMyBids() }
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
                        _state.update {
                            it.copy(
                                items = rows,
                                distanceByJobId = emptyMap(),
                                coordsByJobId = emptyMap(),
                                ownBidsByJob = ownBids,
                                initialLoading = false,
                                refreshing = false,
                                endReached = rows.size < PAGE_SIZE,
                            )
                        }
                    },
                    onFailure = { ex ->
                        _state.update {
                            it.copy(
                                items = emptyList(),
                                distanceByJobId = emptyMap(),
                                initialLoading = false,
                                refreshing = false,
                                errorMessage = ex.toUserMessage(),
                                endReached = true,
                            )
                        }
                    },
                )
            }
        }
    }

    private fun loadNext(page: Int) {
        pageJob?.cancel()
        _state.update { it.copy(loadingMore = true, errorMessage = null) }
        pageJob = viewModelScope.launch {
            val current = _state.value
            // Round 453 fix: capture the query the request was launched
            // for, so the post-update guard can drop the result if the
            // user has typed something new in the meantime. pageJob.cancel
            // is best-effort — if the network result already returned and
            // the success branch is mid-flight, items would otherwise
            // contaminate the new query's list (e.g. 'mri' page-2 rows
            // appended to the 'xray' result).
            val launchedForQuery = current.query
            repository.fetchOpenJobs(
                page = page,
                pageSize = PAGE_SIZE,
                query = launchedForQuery,
            ).fold(
                onSuccess = { rows ->
                    _state.update {
                        if (it.query != launchedForQuery) it
                        else it.copy(
                            items = it.items + rows,
                            loadingMore = false,
                            endReached = rows.size < PAGE_SIZE,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        if (it.query != launchedForQuery) it
                        else it.copy(
                            loadingMore = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
        }
    }
}

/**
 * r1497 — actionable copy shown instead of calling the proximity RPC when the
 * engineer has no service location. Pin the two escape hatches it names: the
 * map's "Set service location" chip and the All radius filter — both exist on
 * the screen and both genuinely resolve the state. (Previously the doomed RPC
 * surfaced the generic 42501 copy "…Try again after KYC is verified", which
 * blamed verification the engineer already has.)
 */
internal const val MISSING_SERVICE_LOCATION_MESSAGE =
    "Nearby jobs need your service location. Tap 'Set service location' on the map, or pick All to browse every open job."

/**
 * Whether the nearby-jobs fetch should be skipped in favour of
 * [MISSING_SERVICE_LOCATION_MESSAGE].
 *
 * True ONLY when all hold:
 *  1. a radius filter is active (radiusKm != null) — the All filter uses the
 *     non-geo open-feed query which works without a base;
 *  2. the query is blank — a text search also routes to the non-geo query;
 *  3. the engineer row has actually LOADED (baseLoaded) — never pre-empt on
 *     coords that are null merely because the fetch hasn't finished/failed;
 *  4. the loaded base coords are absent.
 */
internal fun shouldPreemptNearbyFetch(
    radiusKm: Int?,
    queryIsBlank: Boolean,
    baseLoaded: Boolean,
    baseLatitude: Double?,
    baseLongitude: Double?,
): Boolean = radiusKm != null &&
    queryIsBlank &&
    baseLoaded &&
    (baseLatitude == null || baseLongitude == null)

