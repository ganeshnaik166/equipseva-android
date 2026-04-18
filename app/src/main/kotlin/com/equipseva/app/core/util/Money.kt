package com.equipseva.app.core.util

import java.text.NumberFormat
import java.util.Locale

private val INR: NumberFormat = NumberFormat.getCurrencyInstance(Locale("en", "IN")).apply {
    maximumFractionDigits = 0
    minimumFractionDigits = 0
}

/** Formats a rupee amount as `₹1,800` (no paise, Indian grouping). */
fun formatRupees(amount: Double): String = INR.format(amount)
