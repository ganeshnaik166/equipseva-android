package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SpotAuditQuestionBodyTest {

    @Test fun `with full jobNumber and engineerName`() {
        assertEquals(
            "Job RPR-2026-00041 with Asha Rao just wrapped. Rate the work.",
            spotAuditQuestionBody("RPR-2026-00041", "abcdefgh", "Asha Rao"),
        )
    }

    @Test fun `null jobNumber falls back to RPR + 6-char prefix`() {
        // Critical pin — matches the founder-queue jobNumber fallback
        // convention (take(6) prefix).
        assertEquals(
            "Job RPR-abcdef with Asha Rao just wrapped. Rate the work.",
            spotAuditQuestionBody(null, "abcdefghijkl", "Asha Rao"),
        )
    }

    @Test fun `null engineerName falls back to lowercase the engineer`() {
        // Pin lowercase "the engineer" — flows as a definite article
        // inside a sentence. A refactor to "Engineer" (Title-cased)
        // would read as a proper noun.
        assertEquals(
            "Job RPR-2026-00041 with the engineer just wrapped. Rate the work.",
            spotAuditQuestionBody("RPR-2026-00041", "abc", null),
        )
    }

    @Test fun `both null fall back to RPR-prefix + the engineer`() {
        assertEquals(
            "Job RPR-abcdef with the engineer just wrapped. Rate the work.",
            spotAuditQuestionBody(null, "abcdefghijkl", null),
        )
    }

    @Test fun `Rate the work CTA preserved verbatim`() {
        // Pin literal — "Rate the work" is neutral. A refactor to
        // "Rate the quality" pre-biases toward a quality complaint.
        val out = spotAuditQuestionBody("X", "abc", "Y")
        assertTrue(out.endsWith(" Rate the work."))
    }

    @Test fun `just wrapped phrasing preserved verbatim`() {
        // Pin "just wrapped" — concise + active. A refactor to "was
        // completed" or "finished" loses the immediacy.
        val out = spotAuditQuestionBody("X", "abc", "Y")
        assertTrue(out.contains(" just wrapped. "))
    }

    @Test fun `cross-helper distinction — spot audit vs cash survey question`() {
        // Pin the distinct prompts. Same job context, different
        // questions: cash survey asks about off-platform payment;
        // spot audit asks for a rating.
        val cashBody = cashSurveyQuestionBody("RPR-1", "Asha")
        val auditBody = spotAuditQuestionBody("RPR-1", "abc", "Asha")
        assertEquals(false, cashBody == auditBody)
        assertTrue(cashBody.contains("payment outside"))
        assertTrue(auditBody.contains("Rate the work"))
    }
}
