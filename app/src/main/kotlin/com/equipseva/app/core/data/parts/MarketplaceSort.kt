package com.equipseva.app.core.data.parts

enum class MarketplaceSort(val displayName: String) {
    /** Default — in-stock first, then newest. */
    Relevance("Relevance"),
    PriceAsc("Price: low to high"),
    PriceDesc("Price: high to low"),
    Newest("Newest"),
}
