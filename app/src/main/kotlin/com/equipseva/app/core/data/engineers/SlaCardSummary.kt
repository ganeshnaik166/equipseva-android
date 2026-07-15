package com.equipseva.app.core.data.engineers

import java.util.Locale

/**
 * On-time-delivery band from the SLA card's `on_time_pct`. Pinned cutpoints:
 *   * `excellent` — on-time ≥ 95 %
 *   * `good`      — 85 % ≤ on-time < 95 %
 *   * `attention` — on-time < 85 %
 * These map to the Success / Warn / Danger hero pill. Widening the excellent
 * band would quietly flatter a slipping engineer, so the cut-points are a
 * regression target.
 */
internal fun onTimeBand(onTimePct: Double): String = when {
    onTimePct >= 95.0 -> "excellent"
    onTimePct >= 85.0 -> "good"
    else -> "attention"
}

/**
 * Dispute-rate band from `dispute_rate_pct`:
 *   * `clean`    — exactly 0 %
 *   * `low`      — 0 % < rate < 5 %
 *   * `elevated` — rate ≥ 5 %
 * Zero is called out separately (a "Clean record" badge) because "0 %"
 * deserves a stronger positive than a merely-low rate.
 */
internal fun disputeRateBand(disputeRatePct: Double): String = when {
    disputeRatePct <= 0.0 -> "clean"
    disputeRatePct < 5.0 -> "low"
    else -> "elevated"
}

/**
 * Formats a nullable "hours" duration (accept→arrival, arrival→complete).
 * Null or negative → em dash (no completed jobs in the window to measure).
 * Whole values drop the decimal ("6 h"); fractional keep one ("6.5 h").
 * Locale.ROOT so a comma-decimal locale can't corrupt the number.
 */
internal fun formatSlaHours(hours: Double?): String {
    if (hours == null || hours < 0.0) return "—"
    return if (hours % 1.0 == 0.0) "%.0f h".format(Locale.ROOT, hours)
    else "%.1f h".format(Locale.ROOT, hours)
}
