package com.equipseva.app.features.founder

/**
 * True when a founder list screen should replace its content with the
 * "Couldn't load" empty state.
 *
 * Only when there is nothing to show. A failed pull-to-refresh on a list that
 * already has rows must not wipe those rows: the founder pulls these queues
 * while triaging, and losing the visible rows to a transient network blip
 * reads as "the queue emptied". The KYC / payments / reports queues already
 * behave this way; the AMC-expiring, paused-AMC, inactive-engineer and
 * integrity queues did not.
 */
internal fun founderListShowsErrorState(error: String?, rowCount: Int): Boolean =
    error != null && rowCount == 0

/**
 * Message for the non-destructive refresh-failure banner above a founder list,
 * or null when there is nothing to say there.
 *
 * Complements [founderListShowsErrorState]: exactly one of the two surfaces
 * the failure, so the founder never sees a banner and a full-screen error for
 * the same load.
 */
internal fun founderListRefreshBanner(error: String?, rowCount: Int): String? =
    error?.takeIf { rowCount > 0 }
