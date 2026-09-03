package com.equipseva.app.features.mybids

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Round 3773 — engineer-side "check net payout before you accept"
 * (round502 `profitability_for_repair_bid` / `update_my_profitability_floor`,
 * unread by any client until now). Migration's own pain-point comment:
 * engineers see the gross bid only today and accept jobs that turn out
 * net-negative after platform fee + travel, driving cancellations.
 */
@Singleton
class JobProfitabilityRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Profitability(
        @SerialName("gross_bid_rupees") val grossBidRupees: Double,
        @SerialName("platform_fee_rupees") val platformFeeRupees: Double,
        @SerialName("gst_on_fee_rupees") val gstOnFeeRupees: Double,
        @SerialName("tds_estimate_rupees") val tdsEstimateRupees: Double,
        @SerialName("distance_km") val distanceKm: Double? = null,
        @SerialName("estimated_travel_cost_rupees") val estimatedTravelCostRupees: Double,
        @SerialName("estimated_net_rupees") val estimatedNetRupees: Double,
        @SerialName("profitability_floor_rupees") val profitabilityFloorRupees: Double,
        @SerialName("below_floor") val belowFloor: Boolean,
    )

    suspend fun fetchProfitability(bidId: String): Result<Profitability> = runCatching {
        client.postgrest.rpc(
            function = "profitability_for_repair_bid",
            parameters = buildJsonObject { put("p_bid_id", JsonPrimitive(bidId)) },
        ).decodeSingle<Profitability>()
    }

    suspend fun updateFloor(floorRupees: Double): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "update_my_profitability_floor",
            parameters = buildJsonObject { put("p_floor_rupees", JsonPrimitive(floorRupees)) },
        )
        Unit
    }
}
