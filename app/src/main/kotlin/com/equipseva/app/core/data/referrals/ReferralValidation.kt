package com.equipseva.app.core.data.referrals

/**
 * Client-side validation for a referrer's referral code (the code is the
 * referrer's user_id). Shared by the referrals cockpit
 * (features/engineer) and the referee's join-time capture
 * (features/onboarding).
 *
 *  - blank input → null (no error shown; callers gate submit on
 *    isNotBlank separately)
 *  - the engineer's own code → self-referral, which the server also blocks
 *    (cannot_refer_self); catch it client-side for an instant, friendlier
 *    message
 *  - otherwise null (the server does the authoritative existence checks:
 *    referrer_not_an_engineer / referral_already_registered)
 */
internal fun referralCodeInputError(input: String, ownUserId: String?): String? {
    val code = input.trim()
    if (code.isEmpty()) return null
    if (ownUserId != null && code.equals(ownUserId.trim(), ignoreCase = true)) {
        return "That's your own code — you can't refer yourself."
    }
    return null
}
