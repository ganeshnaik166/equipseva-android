package com.equipseva.app.core.data.invoice

/**
 * Per-fiscal-year roll-up of a user's GST invoices. The platform only
 * exposes the FY/quarter GST summary founder-side (founder_gst_summary,
 * service_role-gated), so the per-user roll-up is derived client-side from
 * the my_gst_invoices() rows.
 */
data class FyInvoiceGroup(
    val fiscalYearLabel: String, // e.g. "FY 2026-27"
    val rows: List<GstInvoiceLedgerRepository.GstInvoiceRow>,
    val invoiceCount: Int,
    val incomingCount: Int,
    val outgoingCount: Int,
    val taxableRupees: Double,
    val gstRupees: Double,
    val totalRupees: Double,
    val rcmCount: Int,
)

/**
 * Indian fiscal-year (Apr 1 – Mar 31) label for an ISO-8601 [issuedAt].
 * Jan–Mar fall in the PREVIOUS calendar year's FY (e.g. 2026-02 → FY
 * 2025-26). Parses only the leading "YYYY-MM" so it's timezone/locale-inert;
 * malformed input falls back to "FY —". End year is 2-digit, zero-padded
 * via Locale.ROOT so a comma-decimal locale can't corrupt it.
 */
internal fun indianFiscalYearLabel(issuedAt: String): String {
    val year = issuedAt.take(4).toIntOrNull() ?: return "FY —"
    val month = issuedAt.drop(5).take(2).toIntOrNull() ?: return "FY —"
    if (month < 1 || month > 12) return "FY —"
    val startYear = if (month >= 4) year else year - 1
    val endYY = (startYear + 1) % 100
    return "FY $startYear-%02d".format(java.util.Locale.ROOT, endYY)
}

/**
 * Groups invoice rows by Indian fiscal year, summing taxable / GST / total
 * and counting direction + RCM per FY. Groups are ordered most-recent-FY
 * first; rows within a group keep the server's issued_at-desc order.
 */
internal fun summariseGstInvoicesByFiscalYear(
    rows: List<GstInvoiceLedgerRepository.GstInvoiceRow>,
): List<FyInvoiceGroup> =
    rows.groupBy { indianFiscalYearLabel(it.issuedAt) }
        .map { (label, groupRows) ->
            // Only status == "issued" invoices count toward the GST position
            // (matches the founder_gst_summary WHERE status='issued' contract).
            // Cancelled/revised rows still appear in the list but must NOT
            // inflate the FY taxable/GST/total — otherwise a refund/credit-note
            // overstates the user's GST liability.
            val issued = groupRows.filter { it.status == "issued" }
            FyInvoiceGroup(
                fiscalYearLabel = label,
                rows = groupRows,
                invoiceCount = groupRows.size,
                incomingCount = groupRows.count { it.direction == "incoming" },
                outgoingCount = groupRows.count { it.direction == "outgoing" },
                taxableRupees = issued.sumOf { it.taxableAmountRupees },
                gstRupees = issued.sumOf { it.totalGstRupees },
                totalRupees = issued.sumOf { it.totalInvoiceRupees },
                rcmCount = groupRows.count { it.rcmApplicable },
            )
        }
        .sortedByDescending { it.fiscalYearLabel }
