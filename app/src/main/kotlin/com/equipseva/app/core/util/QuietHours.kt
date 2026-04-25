package com.equipseva.app.core.util

/**
 * Pure helper for the daily Do-Not-Disturb window. Values are minutes-of-day
 * in [0, 1439]. Wrap-around windows (e.g. 22:00→07:00) are supported: the
 * window is interpreted as `[start, 24:00) ∪ [00:00, end)`. Boundary semantics:
 * `start` is inclusive (quiet starts AT start), `end` is exclusive (quiet ends
 * the instant the clock hits end). When start == end the window is treated as
 * empty so we never silently mute the user forever.
 */
object QuietHours {

    fun isWithinWindow(nowMin: Int, startMin: Int, endMin: Int): Boolean {
        if (startMin == endMin) return false
        return if (startMin < endMin) {
            nowMin >= startMin && nowMin < endMin
        } else {
            // wrap-around: from startMin..23:59 OR 00:00..(endMin-1)
            nowMin >= startMin || nowMin < endMin
        }
    }
}
