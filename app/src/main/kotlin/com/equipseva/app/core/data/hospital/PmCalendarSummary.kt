package com.equipseva.app.core.data.hospital

import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Header roll-up for the PM calendar: how many assets are overdue, due this
 * week, or upcoming. Derived from the per-row [PmCalendarRepository.PmScheduleItem]
 * statuses so the header and row pills share one source of truth.
 */
data class PmCalendarHeadline(
    val total: Int,
    val overdue: Int,
    val dueSoon: Int,
    val upcoming: Int,
)

/**
 * Counts rows by server status. `dueSoon` is the "due" bucket (next PM inside
 * a week); `upcoming` folds both "upcoming" and "scheduled" so the header's
 * three numbers always sum to at most [PmCalendarHeadline.total].
 */
internal fun summarisePmCalendar(
    items: List<PmCalendarRepository.PmScheduleItem>,
): PmCalendarHeadline = PmCalendarHeadline(
    total = items.size,
    overdue = items.count { it.status == "overdue" },
    dueSoon = items.count { it.status == "due" },
    upcoming = items.count { it.status == "upcoming" || it.status == "scheduled" },
)

/**
 * Human "when" line from `days_until_due` (fractional, negative = overdue).
 * Pinned rounding: values within half a day of zero read "Due today"; else
 * round to whole days. Singular/plural handled. A refactor that dropped the
 * "today" window would show "Due in 0 days", which reads as a bug.
 */
internal fun formatDaysUntilDue(days: Double): String {
    if (days <= -0.5) {
        val n = abs(days).roundToInt()
        return "Overdue by $n day${if (n == 1) "" else "s"}"
    }
    if (days < 0.5) return "Due today"
    val n = days.roundToInt()
    return "Due in $n day${if (n == 1) "" else "s"}"
}
