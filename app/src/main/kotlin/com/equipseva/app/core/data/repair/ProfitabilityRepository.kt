package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Engineer bid-profitability estimator (r502). Before accepting a bid, the
 * engineer sees real net pay after the 7% platform fee, GST on that fee, a
 * 194-O TDS estimate, and round-trip travel cost — plus a "below your floor"
 * flag. Read-only estimator + a single-column floor setter; both
 * auth.uid()-scoped, granted to `authenticated`.
 */
@Singleton
class ProfitabilityRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class BidProfitability(
        @SerialName("gross_bid_rupees") val grossBidRupees: Double = 0.0,
        @SerialName("platform_fee_rupees") val platformFeeRupees: Double = 0.0,
        @SerialName("gst_on_fee_rupees") val gstOnFeeRupees: Double = 0.0,
        @SerialName("tds_estimate_rupees") val tdsEstimateRupees: Double = 0.0,
        @SerialName("distance_km") val distanceKm: Double? = null,
        @SerialName("estimated_travel_cost_rupees") val estimatedTravelCostRupees: Double = 0.0,
        @SerialName("estimated_net_rupees") val estimatedNetRupees: Double = 0.0,
        @SerialName("profitability_floor_rupees") val profitabilityFloorRupees: Double = 0.0,
        @SerialName("below_floor") val belowFloor: Boolean = false,
    )

    suspend fun fetchForBid(bidId: String): Result<BidProfitability?> = runCatching {
        client.postgrest.rpc(
            function = "profitability_for_repair_bid",
            parameters = buildJsonObject { put("p_bid_id", JsonPrimitive(bidId)) },
        ).decodeList<BidProfitability>().firstOrNull()
    }

    /** Server clamps to 0..50000 and raises on out-of-range / missing engineer row. */
    suspend fun setFloor(floorRupees: Double): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "update_my_profitability_floor",
            parameters = buildJsonObject { put("p_floor_rupees", JsonPrimitive(floorRupees)) },
        )
        Unit
    }
}
