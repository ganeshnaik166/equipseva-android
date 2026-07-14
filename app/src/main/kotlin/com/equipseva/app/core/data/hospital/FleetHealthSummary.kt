package com.equipseva.app.core.data.hospital

import java.util.Locale

/**
 * Fleet-wide roll-up shown in the header card above the per-asset list.
 * Derived client-side from the [FleetHealthRepository.FleetAsset] rows —
 * the RPC returns one row per asset, not an aggregate.
 */
data class FleetHealthHeadline(
    val totalAssets: Int,
    val replacementCandidates: Int,
    val criticalCount: Int,
    val avgUptimePct: Double,
    val totalDowntimeHours: Double,
)

/**
 * Reliability band from an asset's uptime %. Pinned thresholds:
 *   * `healthy`  — uptime ≥ 98 %
 *   * `watch`    — 90 % ≤ uptime < 98 %
 *   * `critical` — uptime < 90 %
 * These map to the Success / Warn / Danger pills on the row. A refactor that
 * widens the healthy band would quietly downgrade the "critical" nudge the
 * whole screen exists to surface, so the cut-points are a regression target.
 */
internal fun uptimeBand(uptimePct: Double): String = when {
    uptimePct >= 98.0 -> "healthy"
    uptimePct >= 90.0 -> "watch"
    else -> "critical"
}

/**
 * Fleet-wide roll-up for the header. `avgUptimePct` is a simple mean across
 * assets; `criticalCount` reuses [uptimeBand] so the header and the row pills
 * can never disagree on what counts as critical. Empty fleet → all zeros
 * (the screen renders the empty-state instead of the header in that case).
 */
internal fun summariseFleetHealth(
    assets: List<FleetHealthRepository.FleetAsset>,
): FleetHealthHeadline {
    if (assets.isEmpty()) return FleetHealthHeadline(0, 0, 0, 0.0, 0.0)
    return FleetHealthHeadline(
        totalAssets = assets.size,
        replacementCandidates = assets.count { it.replacementCandidate },
        criticalCount = assets.count { uptimeBand(it.uptimePct) == "critical" },
        avgUptimePct = assets.sumOf { it.uptimePct } / assets.size,
        totalDowntimeHours = assets.sumOf { it.totalDowntimeHours },
    )
}

/**
 * Human title for an asset row: "Brand Model" when either is present,
 * otherwise the de-snaked equipment type ("patient_monitoring" → "Patient
 * monitoring"), otherwise a safe "Equipment" fallback so a null-heavy row
 * never renders a blank title.
 */
internal fun fleetAssetTitle(brand: String?, model: String?, equipmentType: String?): String {
    val name = listOfNotNull(brand, model)
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .joinToString(" ")
    if (name.isNotEmpty()) return name
    val type = equipmentType?.trim().orEmpty()
    if (type.isEmpty()) return "Equipment"
    return type.replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/**
 * Formats a nullable "days" metric (MTBF). Null or non-positive → em dash
 * (no failures in the window, or too little data to compute a mean). Whole
 * values drop the decimal ("42 d"); fractional keep one ("0.5 d"). Locale.ROOT
 * so a comma-decimal locale can't corrupt the number.
 */
internal fun formatDayMetric(days: Double?): String {
    if (days == null || days <= 0.0) return "—"
    return if (days % 1.0 == 0.0) "%.0f d".format(Locale.ROOT, days)
    else "%.1f d".format(Locale.ROOT, days)
}

/**
 * Formats a nullable "hours" metric (MTTR, downtime). Null or negative → em
 * dash; zero is a real value and renders "0 h" (e.g. no downtime). Whole
 * values drop the decimal; fractional keep one.
 */
internal fun formatHourMetric(hours: Double?): String {
    if (hours == null || hours < 0.0) return "—"
    return if (hours % 1.0 == 0.0) "%.0f h".format(Locale.ROOT, hours)
    else "%.1f h".format(Locale.ROOT, hours)
}
