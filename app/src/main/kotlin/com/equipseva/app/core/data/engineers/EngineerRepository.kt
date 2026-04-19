package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.repair.RepairEquipmentCategory

interface EngineerRepository {
    suspend fun fetchByUserId(userId: String): Result<Engineer?>

    suspend fun upsert(
        userId: String,
        aadhaarNumber: String?,
        qualifications: List<String>,
        specializations: List<RepairEquipmentCategory>,
        experienceYears: Int,
        serviceRadiusKm: Int,
        city: String?,
        state: String?,
        certificates: List<EngineerCertificate>,
    ): Result<Engineer>

    /**
     * Upsert the engineer self-profile (rate / years / service areas / specializations
     * / bio / availability). Keyed on `user_id` so the same call covers first-time
     * create and subsequent edits. Does not touch KYC columns.
     */
    suspend fun upsertProfile(
        userId: String,
        hourlyRate: Double,
        yearsExperience: Int,
        serviceAreas: List<String>,
        specializations: List<String>,
        bio: String,
        isAvailable: Boolean,
    ): Result<Engineer>

    /**
     * Upload a file (aadhaar photo, certificate, etc.) into the `kyc-docs` bucket
     * under the caller's auth.uid folder. Returns the stored object path.
     */
    suspend fun uploadKycDoc(
        userId: String,
        fileName: String,
        bytes: ByteArray,
        contentType: String?,
    ): Result<String>
}
