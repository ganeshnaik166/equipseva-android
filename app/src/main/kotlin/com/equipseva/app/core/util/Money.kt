package com.equipseva.app.core.util

import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale

// Round 398 — explicit Indian-grouping formatter.
//
// Locale("en","IN") alone does NOT produce Indian-style grouping on
// most JVMs / Android ICU builds; it falls through to Western
// 180,000 instead of the expected 1,80,000. r397 tests surfaced this
// — the assertion had to accept either because the impl couldn't
// guarantee the lakh/crore grouping. Customers see ₹180,000 instead
// of ₹1,80,000 across every money-bearing surface (Payments header,
// Earnings hero, AMC list, dispute card, engineer self-rank).
//
// Use a custom DecimalFormat with the Indian pattern `##,##,##0` to
// force the lakh + crore grouping regardless of JVM ICU. ₹ symbol +
// no paise preserved as before.

private val INR: DecimalFormat = DecimalFormat(
    "₹##,##,##0",
    DecimalFormatSymbols(Locale("en", "IN")),
).apply {
    maximumFractionDigits = 0
    minimumFractionDigits = 0
}

/** Formats a rupee amount as `₹1,80,000` (no paise, Indian lakh/crore grouping). */
fun formatRupees(amount: Double): String = INR.format(amount)
