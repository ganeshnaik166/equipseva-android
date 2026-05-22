package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the cash-survey question body composer. This is the
 * trust-and-safety signal copy the founder uses to investigate
 * cash-flag patterns — pin word-for-word so a UX rewrite is
 * intentional (changes the kind of answers the founder gets).
 */
class CashSurveyQuestionBodyTest {

    @Test fun `composes question with job number and engineer name`() {
        assertEquals(
            "Job RPR-00027 with Ravi Kumar just wrapped. " +
                "Did the engineer ask for any payment outside the app?",
            cashSurveyQuestionBody(
                jobNumber = "RPR-00027",
                engineerName = "Ravi Kumar",
            ),
        )
    }

    @Test fun `phrasing pinned word-for-word (regression — trust-and-safety signal)`() {
        // Pin all the key phrases so a refactor surfaces the
        // change in review. Cash-flag categorisation depends on
        // how the question is asked.
        val out = cashSurveyQuestionBody("RPR-1", "Engineer")
        assertEquals(true, out.contains("just wrapped"))
        assertEquals(true, out.contains("any payment outside the app"))
    }

    @Test fun `single-word engineer name interpolates correctly`() {
        val out = cashSurveyQuestionBody("RPR-1", "Priyanka")
        assertEquals(true, out.contains("with Priyanka"))
    }

    @Test fun `embedded job number renders verbatim (RPR prefix preserved)`() {
        val out = cashSurveyQuestionBody("RPR-00042", "Engineer")
        assertEquals(true, out.contains("Job RPR-00042"))
    }

    @Test fun `engineer name with special chars passes through unchanged`() {
        // Defensive — apostrophe in "O'Reilly" / Devanagari name
        // shouldn't crash the helper. Pin so a refactor that did
        // any normalisation surfaces.
        val out = cashSurveyQuestionBody("RPR-1", "O'Reilly")
        assertEquals(true, out.contains("with O'Reilly just wrapped"))
    }

    @Test fun `body ends with the question (question mark trailing)`() {
        val out = cashSurveyQuestionBody("RPR-1", "Eng")
        assertEquals(true, out.endsWith("?"))
    }
}
