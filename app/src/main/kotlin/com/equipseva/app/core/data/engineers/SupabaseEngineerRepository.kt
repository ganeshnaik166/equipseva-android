package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.storage.StorageRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Singleton
class SupabaseEngineerRepository @Inject constructor(
    private val client: SupabaseClient,
    private val storage: StorageRepository,
) : EngineerRepository {

    override suspend fun fetchByUserId(userId: String): Result<Engineer?> = runCatching {
        client.from(TABLE).select {
            filter { eq("user_id", userId) }
            limit(count = 1)
        }.decodeList<EngineerDto>().firstOrNull()?.toDomain()
    }

    override suspend fun fetchMySuspension(): Result<EngineerRepository.MySuspension?> = runCatching {
        val rows = client.postgrest.rpc(function = "engineer_my_suspension")
            .decodeList<MySuspensionDto>()
        val row = rows.firstOrNull() ?: return@runCatching null
        if (!row.isSuspended) null
        else EngineerRepository.MySuspension(
            suspendedAt = row.suspendedAt,
            reason = row.reason,
            flagCount90d = row.flagCount90d,
        )
    }

    @Serializable
    private data class MySuspensionDto(
        @SerialName("is_suspended") val isSuspended: Boolean = false,
        @SerialName("suspended_at") val suspendedAt: String? = null,
        @SerialName("reason") val reason: String? = null,
        @SerialName("flag_count_90d") val flagCount90d: Int = 0,
    )

    override suspend fun upsert(
        userId: String,
        aadhaarNumber: String?,
        panNumber: String?,
        qualifications: List<String>,
        specializations: List<RepairEquipmentCategory>,
        experienceYears: Int,
        serviceRadiusKm: Int,
        city: String?,
        state: String?,
        latitude: Double?,
        longitude: Double?,
        certificates: List<EngineerCertificate>,
        aadhaarUploaded: Boolean,
        resetVerificationToPending: Boolean,
    ): Result<Engineer> = runCatching {
        val payload = EngineerUpsertDto(
            userId = userId,
            aadhaarNumber = aadhaarNumber?.takeIf { it.isNotBlank() },
            panNumber = panNumber?.takeIf { it.isNotBlank() },
            qualifications = qualifications.ifEmpty { null },
            specializations = specializations.map { it.storageKey }.ifEmpty { null },
            experienceYears = experienceYears,
            serviceRadiusKm = serviceRadiusKm,
            city = city?.takeIf { it.isNotBlank() },
            state = state?.takeIf { it.isNotBlank() },
            latitude = latitude,
            longitude = longitude,
            certificates = certificates.ifEmpty { null },
            aadhaarVerified = if (aadhaarUploaded) true else null,
            verificationStatus = if (resetVerificationToPending) {
                VerificationStatus.Pending.storageKey
            } else {
                null
            },
        )
        client.from(TABLE).upsert(payload) {
            onConflict = "user_id"
            select()
        }.decodeSingle<EngineerDto>().toDomain()
    }

    override suspend fun upsertProfile(
        userId: String,
        hourlyRate: Double,
        yearsExperience: Int,
        serviceAreas: List<String>,
        specializations: List<String>,
        bio: String,
        isAvailable: Boolean,
    ): Result<Engineer> = runCatching {
        // Server CHECK (round284) caps engineers.bio at 1500 chars.
        // EngineerProfileViewModel already clamps the TextField but the
        // repository is the right place to enforce the boundary for
        // non-UI callers (scripts, tests) so a bypass can't write past
        // the cap and trigger a 23514 toast.
        val payload = EngineerProfileUpsertDto(
            userId = userId,
            hourlyRate = hourlyRate,
            yearsExperience = yearsExperience,
            serviceAreas = serviceAreas,
            specializations = specializations,
            bio = bio.take(1500),
            isAvailable = isAvailable,
        )
        client.from(TABLE).upsert(payload) {
            onConflict = "user_id"
            select()
        }.decodeSingle<EngineerDto>().toDomain()
    }

    override suspend fun updateBaseLocation(
        userId: String,
        latitude: Double,
        longitude: Double,
    ): Result<Engineer> = runCatching {
        // Mirror the same auth-id guard used by SupabaseProfileRepository
        // mutations: refuse a caller that hands in someone else's user id.
        // RLS catches the row-write server-side; the local guard fails
        // fast on a logic bug (stale uid across token rotation, etc.).
        val authUid = client.auth.currentUserOrNull()?.id
        require(authUid != null && authUid == userId) {
            "updateBaseLocation refused: signed-in user does not match target id"
        }
        // Also clamp WGS84 ranges + reject NaN. The on-device guard in
        // EngineerLocationViewModel (PR #662) already filters at the UI
        // layer, but this is the last line in front of the network so
        // a future non-UI caller can't bypass the bounds.
        require(latitude in -90.0..90.0 && !latitude.isNaN()) {
            "updateBaseLocation refused: invalid latitude $latitude"
        }
        require(longitude in -180.0..180.0 && !longitude.isNaN()) {
            "updateBaseLocation refused: invalid longitude $longitude"
        }
        client.from(TABLE).update(
            {
                set("latitude", latitude)
                set("longitude", longitude)
            },
        ) {
            filter { eq("user_id", userId) }
            select()
        }.decodeSingle<EngineerDto>().toDomain()
    }

    override suspend fun uploadKycDoc(
        userId: String,
        fileName: String,
        bytes: ByteArray,
        contentType: String?,
    ): Result<String> = runCatching {
        val path = "$userId/$fileName"
        storage.upload(
            bucket = StorageRepository.Buckets.KYC_DOCS,
            path = path,
            bytes = bytes,
            contentType = contentType,
        ).getOrThrow()
        path
    }

    private companion object {
        const val TABLE = "engineers"
    }
}
