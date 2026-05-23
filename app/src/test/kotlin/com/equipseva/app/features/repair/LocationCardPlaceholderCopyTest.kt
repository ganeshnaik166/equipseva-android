package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

class LocationCardPlaceholderCopyTest {

    @Test fun `canShowAddress true returns no-pin copy`() {
        // Address visible but map can't render (legacy backfill row
        // with text address but no lat/lng).
        assertEquals(
            "No map pin saved for this job",
            locationCardPlaceholderCopy(
                canShowAddress = true,
                hasAddressOnFile = true,
                isEngineer = false,
            ),
        )
    }

    @Test fun `no address on file returns generic copy`() {
        assertEquals(
            "No address on file yet",
            locationCardPlaceholderCopy(
                canShowAddress = false,
                hasAddressOnFile = false,
                isEngineer = false,
            ),
        )
    }

    @Test fun `engineer with hidden address sees bid-framed copy`() {
        // Critical regression target — "hospital accepts your bid"
        // framing. Old "accept the job" copy confused engineers
        // looking for an accept button.
        assertEquals(
            "Address hidden until the hospital accepts your bid",
            locationCardPlaceholderCopy(
                canShowAddress = false,
                hasAddressOnFile = true,
                isEngineer = true,
            ),
        )
    }

    @Test fun `non-engineer (hospital) with hidden address sees generic accepted-bid copy`() {
        assertEquals(
            "Address hidden until a bid is accepted",
            locationCardPlaceholderCopy(
                canShowAddress = false,
                hasAddressOnFile = true,
                isEngineer = false,
            ),
        )
    }

    @Test fun `canShowAddress takes priority over hasAddressOnFile`() {
        // Pin precedence — canShowAddress short-circuits before
        // hasAddressOnFile check (would otherwise contradict).
        assertEquals(
            "No map pin saved for this job",
            locationCardPlaceholderCopy(
                canShowAddress = true,
                hasAddressOnFile = false,  // contradictory but pin behaviour
                isEngineer = true,
            ),
        )
    }

    @Test fun `engineer copy says your bid not your job`() {
        // Pin the regression target literal — "your bid" anchors the
        // workflow (engineers bid; hospitals accept). "Your job"
        // would suggest the engineer has agency over acceptance.
        val out = locationCardPlaceholderCopy(false, true, isEngineer = true)
        assertEquals(true, out.contains("your bid"))
        assertEquals(false, out.contains("your job"))
    }
}
