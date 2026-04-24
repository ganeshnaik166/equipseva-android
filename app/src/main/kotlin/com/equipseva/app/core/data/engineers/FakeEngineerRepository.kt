package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.demo.DemoSeed
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory implementation backed by [DemoSeed]. Wired in by [EngineersModule] when
 * `BuildConfig.DEMO_MODE` is true so the hospital-side engineer browse + KYC review
 * screens render rich sample profiles. KYC writes / uploads are no-ops.
 */
@Singleton
class FakeEngineerRepository @Inject constructor() : EngineerRepository {

    override suspend fun fetchByUserId(userId: String): Result<Engineer?> =
        Result.success(DemoSeed.engineers.firstOrNull { it.userId == userId })

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
    ): Result<Engineer> =
        Result.failure(UnsupportedOperationException("Demo mode: engineer KYC upsert is disabled"))

    override suspend fun upsertProfile(
        userId: String,
        hourlyRate: Double,
        yearsExperience: Int,
        serviceAreas: List<String>,
        specializations: List<String>,
        bio: String,
        isAvailable: Boolean,
    ): Result<Engineer> =
        Result.failure(UnsupportedOperationException("Demo mode: engineer profile upsert is disabled"))

    override suspend fun uploadKycDoc(
        userId: String,
        fileName: String,
        bytes: ByteArray,
        contentType: String?,
    ): Result<String> =
        Result.failure(UnsupportedOperationException("Demo mode: KYC uploads are disabled"))
}
