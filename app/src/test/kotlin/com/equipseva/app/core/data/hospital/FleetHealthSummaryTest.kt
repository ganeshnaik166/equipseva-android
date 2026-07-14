package com.equipseva.app.core.data.hospital

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins for the r1396 hospital fleet-health helpers: uptime banding, the
 * fleet-wide roll-up, asset titling, and the MTBF/MTTR/downtime formatters.
 */
class FleetHealthSummaryTest {

    private fun asset(
        type: String? = "patient_monitoring",
        brand: String? = "Philips",
        model: String? = "IntelliVue MX40",
        serial: String? = "SN1",
        failures: Int = 2,
        mtbf: Double? = 42.0,
        mttr: Double? = 6.0,
        downtime: Double = 12.0,
        uptime: Double = 99.0,
        replacement: Boolean = false,
    ) = FleetHealthRepository.FleetAsset(
        equipmentType = type,
        equipmentBrand = brand,
        equipmentModel = model,
        equipmentSerial = serial,
        failureCountWindow = failures,
        mtbfDays = mtbf,
        mttrHours = mttr,
        totalDowntimeHours = downtime,
        uptimePct = uptime,
        replacementCandidate = replacement,
    )

    // ---- uptimeBand ---------------------------------------------------

    @Test fun `uptime at or above 98 is healthy`() {
        assertEquals("healthy", uptimeBand(98.0))
        assertEquals("healthy", uptimeBand(100.0))
    }

    @Test fun `uptime in the 90 to 98 range is watch`() {
        assertEquals("watch", uptimeBand(90.0))
        assertEquals("watch", uptimeBand(97.999))
    }

    @Test fun `uptime below 90 is critical`() {
        assertEquals("critical", uptimeBand(89.99))
        assertEquals("critical", uptimeBand(0.0))
    }

    // ---- summariseFleetHealth -----------------------------------------

    @Test fun `empty fleet rolls up to zeros`() {
        val h = summariseFleetHealth(emptyList())
        assertEquals(0, h.totalAssets)
        assertEquals(0, h.replacementCandidates)
        assertEquals(0, h.criticalCount)
        assertEquals(0.0, h.avgUptimePct, 0.0)
        assertEquals(0.0, h.totalDowntimeHours, 0.0)
    }

    @Test fun `headline counts, means and sums across assets`() {
        val assets = listOf(
            asset(uptime = 100.0, downtime = 10.0, replacement = false), // healthy
            asset(uptime = 95.0, downtime = 20.0, replacement = false),  // watch
            asset(uptime = 80.0, downtime = 30.0, replacement = true),   // critical + candidate
        )
        val h = summariseFleetHealth(assets)
        assertEquals(3, h.totalAssets)
        assertEquals(1, h.replacementCandidates)
        assertEquals(1, h.criticalCount)
        assertEquals(91.6667, h.avgUptimePct, 0.001)
        assertEquals(60.0, h.totalDowntimeHours, 0.0)
    }

    // ---- fleetAssetTitle ----------------------------------------------

    @Test fun `title prefers brand and model`() {
        assertEquals("Philips IntelliVue MX40", fleetAssetTitle("Philips", "IntelliVue MX40", "patient_monitoring"))
    }

    @Test fun `title uses either brand or model alone`() {
        assertEquals("Philips", fleetAssetTitle("Philips", null, "patient_monitoring"))
        assertEquals("IntelliVue MX40", fleetAssetTitle(" ", "IntelliVue MX40", "patient_monitoring"))
    }

    @Test fun `title falls back to de-snaked type then Equipment`() {
        assertEquals("Patient monitoring", fleetAssetTitle(null, "", "patient_monitoring"))
        assertEquals("Equipment", fleetAssetTitle(null, null, null))
        assertEquals("Equipment", fleetAssetTitle("", "", "  "))
    }

    // ---- formatDayMetric / formatHourMetric ---------------------------

    @Test fun `day metric drops decimal when whole, keeps one otherwise`() {
        assertEquals("42 d", formatDayMetric(42.0))
        assertEquals("0.5 d", formatDayMetric(0.5))
    }

    @Test fun `day metric null or non-positive is em dash`() {
        assertEquals("—", formatDayMetric(null))
        assertEquals("—", formatDayMetric(0.0))
        assertEquals("—", formatDayMetric(-3.0))
    }

    @Test fun `hour metric shows zero but em-dashes null and negative`() {
        assertEquals("0 h", formatHourMetric(0.0))
        assertEquals("6 h", formatHourMetric(6.0))
        assertEquals("6.5 h", formatHourMetric(6.5))
        assertEquals("—", formatHourMetric(null))
        assertEquals("—", formatHourMetric(-1.0))
    }
}
