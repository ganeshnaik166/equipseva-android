package com.equipseva.app.features.repair.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class RepeatBookingNudgeTitleTest {

    @Test fun `composes engineer name + distance with km away suffix`() {
        assertEquals(
            "Asha Rao is 3.2 km away",
            repeatBookingNudgeTitle("Asha Rao", 3.2),
        )
    }

    @Test fun `Locale-US stable across hi-IN`() {
        // Pin — hi-IN would render "3,2 km away" if Locale.US dropped.
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("hi-IN"))
            assertEquals(
                "Asha Rao is 3.2 km away",
                repeatBookingNudgeTitle("Asha Rao", 3.2),
            )
            Locale.setDefault(Locale.GERMANY)
            assertEquals(
                "Asha Rao is 3.2 km away",
                repeatBookingNudgeTitle("Asha Rao", 3.2),
            )
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun `whole km distance still shows one decimal`() {
        assertEquals(
            "Asha Rao is 5.0 km away",
            repeatBookingNudgeTitle("Asha Rao", 5.0),
        )
    }

    @Test fun `is X km away frame preserved over compact form`() {
        // Pin "is N km away" subject-verb sentence shape. A refactor
        // to "Engineer · Y km away" would lose the framing that this
        // engineer is FAR (the reason for the nudge).
        val out = repeatBookingNudgeTitle("X", 1.0)
        assertTrue(out.contains(" is "))
        assertTrue(out.endsWith(" km away"))
    }

    @Test fun `engineer name passes through verbatim`() {
        assertEquals(
            "Dr. K Ramesh is 1.5 km away",
            repeatBookingNudgeTitle("Dr. K Ramesh", 1.5),
        )
    }

    @Test fun `rounds to one decimal half-up`() {
        assertEquals(
            "X is 3.3 km away",
            repeatBookingNudgeTitle("X", 3.25),
        )
    }
}
