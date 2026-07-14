package com.equipseva.app.core.data.payouts

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1393 TDS (194-O) fiscal-year roll-up. */
class TdsSummaryTest {

    private fun q(
        quarter: String = "Q1",
        gross: Double = 1000.0,
        tds: Double = 10.0,
        net: Double = 990.0,
        count: Long = 2,
        fy: String = "2026-27",
    ) = TdsSummaryRepository.TdsQuarterRow(
        fiscalYear = fy,
        fyQuarter = quarter,
        grossRupees = gross,
        tdsRupees = tds,
        netPayableRupees = net,
        deductionCount = count,
    )

    @Test fun `empty statement rolls up to zeros with dash FY and zero rate`() {
        val t = rollUpTdsAcrossQuarters(emptyList())
        assertEquals("—", t.fiscalYear)
        assertEquals(0.0, t.grossRupees, 0.0)
        assertEquals(0.0, t.tdsRupees, 0.0)
        assertEquals(0L, t.deductionCount)
        assertEquals(0.0, t.effectiveTdsRatePct, 0.0)
    }

    @Test fun `quarters sum and the effective rate is tds over gross`() {
        val t = rollUpTdsAcrossQuarters(
            listOf(
                q(quarter = "Q1", gross = 1000.0, tds = 10.0, net = 990.0, count = 2),
                q(quarter = "Q2", gross = 3000.0, tds = 30.0, net = 2970.0, count = 3),
            ),
        )
        assertEquals("2026-27", t.fiscalYear)
        assertEquals(4000.0, t.grossRupees, 0.0)
        assertEquals(40.0, t.tdsRupees, 0.0)
        assertEquals(3960.0, t.netPayableRupees, 0.0)
        assertEquals(5L, t.deductionCount)
        assertEquals(1.0, t.effectiveTdsRatePct, 0.0001) // 40 / 4000 * 100
    }

    @Test fun `zero gross yields a zero rate, never a divide-by-zero`() {
        val t = rollUpTdsAcrossQuarters(listOf(q(gross = 0.0, tds = 0.0, net = 0.0, count = 0)))
        assertEquals(0.0, t.effectiveTdsRatePct, 0.0)
    }
}
