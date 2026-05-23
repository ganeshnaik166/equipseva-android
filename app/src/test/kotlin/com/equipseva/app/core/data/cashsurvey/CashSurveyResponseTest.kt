package com.equipseva.app.core.data.cashsurvey

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the wire-string contract on [CashSurveyRepository.Response].
 * The server-side `submit_cash_survey` RPC has a CHECK constraint on
 * `cash_payment_surveys.response` that matches these keys verbatim —
 * a rename would silently 23514 every submission.
 */
class CashSurveyResponseTest {

    @Test fun `storage keys match the CHECK constraint values`() {
        assertEquals("asked_cash", CashSurveyRepository.Response.AskedCash.storageKey)
        assertEquals("no_cash", CashSurveyRepository.Response.NoCash.storageKey)
        assertEquals("declined", CashSurveyRepository.Response.Declined.storageKey)
    }

    @Test fun `keys are all distinct`() {
        val keys = CashSurveyRepository.Response.entries.map { it.storageKey }
        assertEquals(keys.size, keys.toSet().size)
    }

    @Test fun `there are exactly three response options`() {
        // Pin so a future addition (e.g. "unsure") is reviewed —
        // adding a fourth requires a coordinated DB CHECK migration
        // and a UI option.
        assertEquals(3, CashSurveyRepository.Response.entries.size)
    }
}
