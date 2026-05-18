package com.equipseva.app.core.data.addresses

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

@Singleton
class AddressRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class UserAddress(
        @SerialName("id") val id: String? = null,
        @SerialName("user_id") val userId: String? = null,
        @SerialName("label") val label: String? = null,
        @SerialName("full_name") val fullName: String,
        @SerialName("phone") val phone: String,
        @SerialName("line1") val line1: String,
        @SerialName("line2") val line2: String? = null,
        @SerialName("landmark") val landmark: String? = null,
        @SerialName("city") val city: String,
        @SerialName("state") val state: String,
        @SerialName("pincode") val pincode: String,
        @SerialName("is_default") val isDefault: Boolean = false,
        @SerialName("latitude") val latitude: Double? = null,
        @SerialName("longitude") val longitude: Double? = null,
        @SerialName("created_at") val createdAt: String? = null,
        @SerialName("updated_at") val updatedAt: String? = null,
    )

    suspend fun list(): Result<List<UserAddress>> = runCatching {
        client.postgrest.from("user_addresses")
            .select {
                order("is_default", Order.DESCENDING)
                order("created_at", Order.DESCENDING)
            }
            .decodeList<UserAddress>()
    }

    suspend fun upsert(address: UserAddress): Result<UserAddress> = runCatching {
        val uid = client.auth.currentUserOrNull()?.id
            ?: error("not_authenticated")
        // Round 281 added server CHECKs (label ≤ 80, full_name/line1/line2/
        // landmark ≤ 200, city ≤ 120, state ≤ 80) and matching UI caps in
        // AddressFormScreen. Defense-in-depth at the repo boundary so a
        // non-UI caller (deeplink-from-share-sheet, future bulk import,
        // tests) can't smuggle past-cap strings to a 23514 toast.
        val capped = address.copy(
            userId = uid,
            label = address.label?.take(80),
            fullName = address.fullName.take(200),
            line1 = address.line1.take(200),
            line2 = address.line2?.take(200),
            landmark = address.landmark?.take(200),
            city = address.city.take(120),
            state = address.state.take(80),
        )
        val withOwner = capped
        if (address.id == null) {
            client.postgrest.from("user_addresses")
                .insert(withOwner) { select() }
                .decodeSingle<UserAddress>()
        } else {
            // Round 338 — .decodeSingle() raises NoSuchElementException
            // when an UPDATE returns 0 rows (stale id, RLS rejection,
            // address deleted in another session). Surface a clear
            // error to the caller instead of letting the deserializer
            // throw cryptically.
            client.postgrest.from("user_addresses")
                .update(withOwner) {
                    filter {
                        eq("id", address.id)
                        eq("user_id", uid)
                    }
                    select()
                }
                .decodeSingleOrNull<UserAddress>()
                ?: error("Address not found or no permission")
        }
    }

    suspend fun delete(id: String): Result<Unit> = runCatching {
        // Defense-in-depth: pair the row id with the caller's auth.uid so a
        // forged delete can't take out someone else's address row. RLS
        // already enforces this server-side, but the client-side filter
        // makes a stale-id logic bug throw locally instead of silently
        // no-op'ing against an empty filter set. Same pattern as
        // `update()` above.
        val uid = client.auth.currentUserOrNull()?.id
            ?: error("Sign in to delete addresses.")
        client.postgrest.from("user_addresses")
            .delete {
                filter {
                    eq("id", id)
                    eq("user_id", uid)
                }
            }
        Unit
    }

    suspend fun setDefault(id: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "address_set_default",
            parameters = buildJsonObject {
                put("p_address_id", JsonPrimitive(id))
            },
        )
        Unit
    }
}
