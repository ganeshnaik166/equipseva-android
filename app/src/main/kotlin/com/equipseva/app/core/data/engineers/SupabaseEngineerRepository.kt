package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.storage.StorageRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import javax.inject.Inject
import javax.inject.Singleton

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

    override suspend fun upsert(
        userId: String,
        aadhaarNumber: String?,
        qualifications: List<String>,
        specializations: List<RepairEquipmentCategory>,
        experienceYears: Int,
        serviceRadiusKm: Int,
        city: String?,
        state: String?,
        certificates: List<EngineerCertificate>,
        resetVerificationToPending: Boolean,
    ): Result<Engineer> = runCatching {
        val payload = EngineerUpsertDto(
            userId = userId,
            aadhaarNumber = aadhaarNumber?.takeIf { it.isNotBlank() },
            qualifications = qualifications.ifEmpty { null },
            specializations = specializations.map { it.storageKey }.ifEmpty { null },
            experienceYears = experienceYears,
            serviceRadiusKm = serviceRadiusKm,
            city = city?.takeIf { it.isNotBlank() },
            state = state?.takeIf { it.isNotBlank() },
            certificates = certificates.ifEmpty { null },
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
        val payload = EngineerProfileUpsertDto(
            userId = userId,
            hourlyRate = hourlyRate,
            yearsExperience = yearsExperience,
            serviceAreas = serviceAreas,
            specializations = specializations,
            bio = bio,
            isAvailable = isAvailable,
        )
        client.from(TABLE).upsert(payload) {
            onConflict = "user_id"
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
