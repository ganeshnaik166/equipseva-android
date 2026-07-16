package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1420 founder metric-cockpit helpers. */
class FounderMetricHelpersTest {

    @Test fun `metric label de-snakes and capitalises`() {
        assertEquals("Total revenue inr", metricLabel("total_revenue_inr"))
        assertEquals("Active engineers", metricLabel("active_engineers"))
        assertEquals("Already human", metricLabel("Already human"))
    }

    @Test fun `metric number drops redundant decimal`() {
        assertEquals("12", formatMetricNumber(12.0))
        assertEquals("12.5", formatMetricNumber(12.5))
    }

    @Test fun `dashboards are code-listed founder RPCs`() {
        assertEquals(true, FOUNDER_METRIC_DASHBOARDS.isNotEmpty())
        assertEquals(true, FOUNDER_METRIC_DASHBOARDS.all { it.rpc.startsWith("founder_") })
    }
}
