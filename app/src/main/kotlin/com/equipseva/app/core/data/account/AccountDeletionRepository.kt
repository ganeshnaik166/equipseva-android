package com.equipseva.app.core.data.account

interface AccountDeletionRepository {
    /**
     * Scrubs PII on the signed-in user's profile, records a pending deletion,
     * and drops their push-device tokens. The caller must invoke sign-out
     * afterwards; hard removal of the auth.users row is performed server-side
     * by a scheduled sweeper after the DPDP 30-day grace window.
     */
    suspend fun deleteMyAccount(reason: String?): Result<Unit>
}
