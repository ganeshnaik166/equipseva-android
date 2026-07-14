package com.equipseva.app.core.data.payouts

/**
 * Financial-year roll-up of an engineer's quarterly TDS rows. [effectiveTdsRatePct]
 * is TDS / gross × 100 (0 when gross is 0, so a no-earnings FY never divides by
 * zero). fiscalYear falls back to "—" for an empty statement.
 */
data class TdsFyTotal(
    val fiscalYear: String,
    val grossRupees: Double,
    val tdsRupees: Double,
    val netPayableRupees: Double,
    val deductionCount: Long,
    val effectiveTdsRatePct: Double,
)

internal fun rollUpTdsAcrossQuarters(
    rows: List<TdsSummaryRepository.TdsQuarterRow>,
): TdsFyTotal {
    val gross = rows.sumOf { it.grossRupees }
    val tds = rows.sumOf { it.tdsRupees }
    val net = rows.sumOf { it.netPayableRupees }
    val count = rows.sumOf { it.deductionCount }
    val fy = rows.firstOrNull()?.fiscalYear ?: "—"
    val rate = if (gross > 0.0) tds / gross * 100.0 else 0.0
    return TdsFyTotal(
        fiscalYear = fy,
        grossRupees = gross,
        tdsRupees = tds,
        netPayableRupees = net,
        deductionCount = count,
        effectiveTdsRatePct = rate,
    )
}
