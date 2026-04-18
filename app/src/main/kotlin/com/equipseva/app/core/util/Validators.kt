package com.equipseva.app.core.util

object Validators {

    private val EMAIL_REGEX = Regex(
        "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$",
    )

    fun emailIsValid(email: String): Boolean =
        email.isNotBlank() && EMAIL_REGEX.matches(email.trim())

    /**
     * Minimum strength: 8+ chars, at least one letter and one digit.
     * Stricter than Supabase's default to avoid easy-guess accounts in healthcare context.
     */
    fun passwordIsStrong(password: String): Boolean {
        if (password.length < 8) return false
        val hasLetter = password.any { it.isLetter() }
        val hasDigit = password.any { it.isDigit() }
        return hasLetter && hasDigit
    }

    fun passwordWeakness(password: String): String? = when {
        password.length < 8 -> "Use at least 8 characters"
        password.none { it.isLetter() } -> "Include at least one letter"
        password.none { it.isDigit() } -> "Include at least one number"
        else -> null
    }

    fun otpIsSixDigit(code: String): Boolean =
        code.length == 6 && code.all { it.isDigit() }
}
