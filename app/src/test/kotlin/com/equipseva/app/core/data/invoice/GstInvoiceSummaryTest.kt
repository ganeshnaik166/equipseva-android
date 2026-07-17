package com.equipseva.app.core.data.invoice

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins for the r1392 GST-invoice FY roll-up (the per-user summary the
 * platform only exposes founder-side). Indian FY = Apr 1 – Mar 31.
 */
class GstInvoiceSummaryTest {

    private fun inv(
        id: String = "i1",
        direction: String = "incoming",
        taxable: Double = 1000.0,
        gst: Double = 180.0,
        total: Double = 1180.0,
        rcm: Boolean = false,
        issuedAt: String = "2026-05-01T10:00:00Z",
    ) = GstInvoiceLedgerRepository.GstInvoiceRow(
        id = id,
        invoiceSerial = "INV-$id",
        direction = direction,
        counterpartyName = "Counterparty",
        sourceKind = "repair",
        taxableAmountRupees = taxable,
        totalGstRupees = gst,
        totalInvoiceRupees = total,
        rcmApplicable = rcm,
        status = "issued",
        issuedAt = issuedAt,
    )

    // ---- indianFiscalYearLabel ----------------------------------------

    @Test fun `april starts a new fiscal year`() {
        assertEquals("FY 2026-27", indianFiscalYearLabel("2026-04-01T00:00:00Z"))
    }

    @Test fun `march belongs to the prior fiscal year`() {
        assertEquals("FY 2025-26", indianFiscalYearLabel("2026-03-31T23:59:59Z"))
    }

    @Test fun `may is in the current fiscal year`() {
        assertEquals("FY 2026-27", indianFiscalYearLabel("2026-05-01T10:00:00Z"))
    }

    @Test fun `end year is two-digit zero-padded`() {
        assertEquals("FY 2006-07", indianFiscalYearLabel("2006-08-01T00:00:00Z"))
    }

    @Test fun `malformed timestamps fall back to FY dash`() {
        assertEquals("FY —", indianFiscalYearLabel(""))
        assertEquals("FY —", indianFiscalYearLabel("not-a-date"))
        assertEquals("FY —", indianFiscalYearLabel("2026-13-01T00:00:00Z"))
    }

    // ---- summariseGstInvoicesByFiscalYear -----------------------------

    @Test fun `empty rows produce no groups`() {
        assertEquals(0, summariseGstInvoicesByFiscalYear(emptyList()).size)
    }

    @Test fun `cancelled and revised invoices are excluded from GST sums (r1469)`() {
        // A cancelled/revised invoice still shows in the list (invoiceCount) but
        // must not inflate the FY taxable/GST/total — matches founder_gst_summary.
        val rows = listOf(
            inv(id = "a", taxable = 1000.0, gst = 180.0, total = 1180.0).copy(status = "issued"),
            inv(id = "b", taxable = 5000.0, gst = 900.0, total = 5900.0).copy(status = "cancelled"),
            inv(id = "c", taxable = 3000.0, gst = 540.0, total = 3540.0).copy(status = "revised"),
        )
        val g = summariseGstInvoicesByFiscalYear(rows).single()
        assertEquals(3, g.invoiceCount) // all rows still listed
        assertEquals(1000.0, g.taxableRupees, 0.0) // only the issued row counts
        assertEquals(180.0, g.gstRupees, 0.0)
        assertEquals(1180.0, g.totalRupees, 0.0)
    }

    @Test fun `groups by fiscal year, most recent first, summing and counting`() {
        val rows = listOf(
            inv(id = "a", direction = "incoming", taxable = 1000.0, gst = 180.0, total = 1180.0, issuedAt = "2026-05-01T00:00:00Z"),
            inv(id = "b", direction = "outgoing", taxable = 2000.0, gst = 360.0, total = 2360.0, rcm = true, issuedAt = "2026-02-01T00:00:00Z"),
            inv(id = "c", direction = "incoming", taxable = 500.0, gst = 90.0, total = 590.0, issuedAt = "2025-06-01T00:00:00Z"),
        )
        val groups = summariseGstInvoicesByFiscalYear(rows)
        assertEquals(2, groups.size)

        // Most-recent FY first.
        assertEquals("FY 2026-27", groups[0].fiscalYearLabel)
        assertEquals(1, groups[0].invoiceCount)
        assertEquals(1, groups[0].incomingCount)
        assertEquals(0, groups[0].outgoingCount)
        assertEquals(1000.0, groups[0].taxableRupees, 0.0)

        // FY 2025-26 aggregates b (Feb) + c (Jun 2025).
        assertEquals("FY 2025-26", groups[1].fiscalYearLabel)
        assertEquals(2, groups[1].invoiceCount)
        assertEquals(1, groups[1].incomingCount)
        assertEquals(1, groups[1].outgoingCount)
        assertEquals(2500.0, groups[1].taxableRupees, 0.0)
        assertEquals(450.0, groups[1].gstRupees, 0.0)
        assertEquals(2950.0, groups[1].totalRupees, 0.0)
        assertEquals(1, groups[1].rcmCount)
    }
}
