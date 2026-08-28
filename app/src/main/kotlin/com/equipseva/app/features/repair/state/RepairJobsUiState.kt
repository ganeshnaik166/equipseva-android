package com.equipseva.app.features.repair.state

import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairJob

/**
 * Single state object the repair feed screen reads. Matches the shape of the
 * marketplace one so the two screens behave consistently (pull-to-refresh,
 * paging, error banner).
 */
data class RepairJobsUiState(
    val query: String = "",
    val items: List<RepairJob> = emptyList(),
    val initialLoading: Boolean = true,
    val refreshing: Boolean = false,
    val loadingMore: Boolean = false,
    val endReached: Boolean = false,
    val errorMessage: String? = null,
    /**
     * Engineer's own bid keyed by repair job id. Lets each card show whether
     * the viewer has already bid on the job without an extra network hop.
     */
    val ownBidsByJob: Map<String, RepairBid> = emptyMap(),
    /**
     * Distance filter for the open-feed (km). `null` disables the filter and
     * falls back to the unfiltered open-feed query. Default 50 km matches the
     * KYC default service radius engineers register with.
     */
    val radiusKm: Int? = 50,
    /** Distance from engineer base coords to each open-feed job, by job id. */
    val distanceByJobId: Map<String, Double> = emptyMap(),
    /** Hospital coords for each open-feed job, by job id. Used by the map. */
    val coordsByJobId: Map<String, Pair<Double, Double>> = emptyMap(),
    /** Engineer's registered base coords; null until KYC has them. */
    val baseLatitude: Double? = null,
    val baseLongitude: Double? = null,
    /**
     * r1497 — true once the engineer row has been fetched, so null base
     * coords can be trusted to mean "no service location set" (vs "still
     * loading"). Gates the nearby-feed pre-empt: without a base the
     * proximity RPC always fails server-side with a misleading generic
     * 42501 ("try again after KYC is verified"), so the feed shows an
     * actionable set-your-location message instead of calling it.
     */
    val baseLoaded: Boolean = false,
)
