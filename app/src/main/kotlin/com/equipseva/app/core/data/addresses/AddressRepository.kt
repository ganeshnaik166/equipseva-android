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
        val withOwner = address.copy(userId = uid)
        if (address.id == null) {
            client.postgrest.from("user_addresses")
                .insert(withOwner) { select() }
                .decodeSingle<UserAddress>()
        } else {
            client.postgrest.from("user_addresses")
                .update(withOwner) {
                    filter { eq("id", address.id) }
                    select()
                }
                .decodeSingle<UserAddress>()
        }
    }

    suspend fun delete(id: String): Result<Unit> = runCatching {
        client.postgrest.from("user_addresses")
            .delete { filter { eq("id", id) } }
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
