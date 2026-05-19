package com.equipseva.app.core.util

// Round 398 / 408 — Indian lakh-crore grouping, manually applied.
//
// History:
//   r397 surfaced that Locale("en","IN") on the JVM does not always
//   produce Indian grouping; tests had to accept either form.
//   r398 attempted a fix via DecimalFormat("₹##,##,##0", …) — but
//   DecimalFormat only honours a single grouping size (the rightmost
//   comma in the pattern), so the output stayed Western (180,000).
//   r408 tightened the tests to require Indian grouping exclusively
//   and the asserts failed, surfacing that r398's fix did not actually
//   take effect.
//
//   The portable way is to group manually: rightmost 3 digits, then
//   pairs of 2 going left. ₹120000000 → "₹12,00,00,000".

private fun groupIndian(absValue: Long): String {
    val s = absValue.toString()
    if (s.length <= 3) return s
    val last3 = s.substring(s.length - 3)
    val rest = s.substring(0, s.length - 3)
    val sb = StringBuilder()
    var i = rest.length
    while (i > 2) {
        if (sb.isNotEmpty()) sb.insert(0, ',')
        sb.insert(0, rest.substring(i - 2, i))
        i -= 2
    }
    if (i > 0) {
        if (sb.isNotEmpty()) sb.insert(0, ',')
        sb.insert(0, rest.substring(0, i))
    }
    return "$sb,$last3"
}

/** Formats a rupee amount as `₹1,80,000` (no paise, Indian lakh/crore grouping). */
fun formatRupees(amount: Double): String {
    val rounded = kotlin.math.round(amount).toLong()
    val sign = if (rounded < 0) "-" else ""
    val abs = kotlin.math.abs(rounded)
    return "$sign₹${groupIndian(abs)}"
}
