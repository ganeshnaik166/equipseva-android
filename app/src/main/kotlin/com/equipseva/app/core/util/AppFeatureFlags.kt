package com.equipseva.app.core.util

/**
 * Single source of truth for cross-feature toggles. Every flag here is a
 * compile-time `const` so kotlinc inlines the read at every call site and
 * release-build R8 can prune the unreachable branches outright.
 *
 * v1 ships only Book Repair + Engineer Jobs. The Marketplace surface
 * (Buy/Sell tab, catalogue browse, AddListing, Cart, Checkout, Orders,
 * MyListings, hospital-procurement RFQs) is fully wired in code but
 * gated off here. v2 flips MARKETPLACE_ENABLED to true and the whole
 * surface comes back — no code archaeology required.
 */
object AppFeatureFlags {

    /**
     * Marketplace = Buy/Sell tab + Catalogue browse + AddListing + Cart +
     * Checkout + Orders + MyListings + supplier RFQs. All those screens
     * still exist and compile; their entry points (Home Hub tile, bottom
     * nav tab, Profile rows) are conditionally rendered on this flag.
     *
     * v1: false. v2: flip to true and re-release.
     */
    const val MARKETPLACE_ENABLED: Boolean = false
}
