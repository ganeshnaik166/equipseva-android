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
