package com.equipseva.app.features.kyc

/**
 * Verhoeff checksum verifier for 12-digit Aadhaar numbers. Cheaply rejects
 * fake / mistyped numbers client-side without an API call. UIDAI uses this
 * algorithm for the trailing check digit on every Aadhaar.
 *
 * Source: https://en.wikipedia.org/wiki/Verhoeff_algorithm
 */
internal object AadhaarValidator {

    private val d = arrayOf(
        intArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
        intArrayOf(1, 2, 3, 4, 0, 6, 7, 8, 9, 5),
        intArrayOf(2, 3, 4, 0, 1, 7, 8, 9, 5, 6),
        intArrayOf(3, 4, 0, 1, 2, 8, 9, 5, 6, 7),
        intArrayOf(4, 0, 1, 2, 3, 9, 5, 6, 7, 8),
        intArrayOf(5, 9, 8, 7, 6, 0, 4, 3, 2, 1),
        intArrayOf(6, 5, 9, 8, 7, 1, 0, 4, 3, 2),
        intArrayOf(7, 6, 5, 9, 8, 2, 1, 0, 4, 3),
        intArrayOf(8, 7, 6, 5, 9, 3, 2, 1, 0, 4),
        intArrayOf(9, 8, 7, 6, 5, 4, 3, 2, 1, 0),
    )

    private val p = arrayOf(
        intArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
        intArrayOf(1, 5, 7, 6, 2, 8, 3, 0, 9, 4),
        intArrayOf(5, 8, 0, 3, 7, 9, 6, 1, 4, 2),
        intArrayOf(8, 9, 1, 6, 0, 4, 3, 5, 2, 7),
        intArrayOf(9, 4, 5, 3, 1, 2, 6, 8, 7, 0),
        intArrayOf(4, 2, 8, 6, 5, 7, 3, 9, 0, 1),
        intArrayOf(2, 7, 9, 3, 8, 0, 6, 4, 1, 5),
        intArrayOf(7, 0, 4, 6, 9, 1, 3, 2, 5, 8),
    )

    /**
     * Returns true when [number] is exactly 12 digits and the trailing digit
     * passes the Verhoeff check. Empty / partial inputs return false (caller
     * decides what to surface).
     */
    fun isValid(number: String): Boolean {
        if (number.length != 12 || number.any { !it.isDigit() }) return false
        // Aadhaar can't start with 0 or 1 by spec.
        if (number[0] == '0' || number[0] == '1') return false
        var c = 0
        val digits = number.reversed()
        for (i in digits.indices) {
            val n = digits[i] - '0'
            c = d[c][p[i % 8][n]]
        }
        return c == 0
    }
}
