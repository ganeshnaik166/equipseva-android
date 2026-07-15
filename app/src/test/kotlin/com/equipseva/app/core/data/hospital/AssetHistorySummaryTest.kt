package com.equipseva.app.core.data.hospital

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1399 asset-history event labels. */
class AssetHistorySummaryTest {

    @Test fun `known event kinds map to human labels`() {
        assertEquals("Repair job", assetEventLabel("repair_job"))
        assertEquals("Service report", assetEventLabel("dsr_report"))
        assertEquals("Preventive maintenance", assetEventLabel("pm_scheduled"))
    }

    @Test fun `unknown kind de-snakes and capitalises`() {
        assertEquals("Calibration event", assetEventLabel("calibration_event"))
        assertEquals("Recall", assetEventLabel("recall"))
    }
}
