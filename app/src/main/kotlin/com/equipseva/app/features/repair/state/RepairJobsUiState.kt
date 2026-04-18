package com.equipseva.app.features.repair.state

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
)
