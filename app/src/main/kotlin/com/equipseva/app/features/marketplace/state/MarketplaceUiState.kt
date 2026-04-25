package com.equipseva.app.features.marketplace.state

import com.equipseva.app.core.data.parts.MarketplaceSort
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.core.data.parts.SparePart

/**
 * Single state object the marketplace list screen renders. All transient flags
 * (loading, refreshing, paging) live alongside the data so the screen reads one
 * value and never coordinates multiple flows itself.
 */
data class MarketplaceUiState(
    val query: String = "",
    val selectedCategory: PartCategory? = null,
    val sort: MarketplaceSort = MarketplaceSort.Relevance,
    val items: List<SparePart> = emptyList(),
    /** "spare_part" / "equipment" / null = umbrella browse. Drives Marketplace vs Parts tab split. */
    val listingType: String? = null,
    val initialLoading: Boolean = true,
    val refreshing: Boolean = false,
    val loadingMore: Boolean = false,
    val endReached: Boolean = false,
    val errorMessage: String? = null,
)
