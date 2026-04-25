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
     * Jobs assigned to the engineer across all statuses. Separate list because
     * the open-feed query deliberately filters out jobs that have already
     * moved past Requested, so the "My jobs" tab would otherwise be empty.
     */
    val mineItems: List<RepairJob> = emptyList(),
    val mineLoading: Boolean = true,
    val mineErrorMessage: String? = null,
    /**
     * Distance filter for the open-feed (km). `null` disables the filter and
     * falls back to the unfiltered open-feed query. Default 50 km matches the
     * KYC default service radius engineers register with.
     */
    val radiusKm: Int? = 50,
    /** Distance from engineer base coords to each open-feed job, by job id. */
    val distanceByJobId: Map<String, Double> = emptyMap(),
)
