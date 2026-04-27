package com.equipseva.app.core.data.engineers

import com.equipseva.app.core.data.repair.RepairEquipmentCategory

data class Engineer(
    val id: String,
    val userId: String,
    val aadhaarNumber: String?,
    val aadhaarVerified: Boolean,
    val qualifications: List<String>,
    val specializations: List<RepairEquipmentCategory>,
    val brandsServiced: List<String>,
    val experienceYears: Int,
    val serviceRadiusKm: Int,
    val city: String?,
    val state: String?,
    val verificationStatus: VerificationStatus,
    val verificationNotes: String? = null,
    val rejectedDocTypes: List<String> = emptyList(),
    val backgroundCheckStatus: VerificationStatus,
    val certificates: List<EngineerCertificate>,
    // Engineer self-profile fields. Defaults so existing callers (KYC tests, etc.) that
    // don't yet supply these still compile. Nullable rate/years/bio mean "not yet set".
    val hourlyRate: Double? = null,
    val yearsExperience: Int? = null,
    val serviceAreas: List<String> = emptyList(),
    val bio: String? = null,
    val isAvailable: Boolean = true,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val ratingAvg: Double? = null,
    val totalJobs: Int? = null,
    val completionRate: Double? = null,
) {
    val aadhaarDocPath: String? get() =
        certificates.lastOrNull { it.type == EngineerCertificate.TYPE_AADHAAR }?.path

    val certDocPaths: List<String> get() =
        certificates.filter { it.type == EngineerCertificate.TYPE_CERT }.map { it.path }

    val selfieDocPath: String? get() =
        certificates.lastOrNull { it.type == EngineerCertificate.TYPE_SELFIE }?.path
}

internal fun EngineerDto.toDomain(): Engineer = Engineer(
    id = id,
    userId = userId,
    aadhaarNumber = aadhaarNumber?.takeIf { it.isNotBlank() },
    aadhaarVerified = aadhaarVerified ?: false,
    qualifications = qualifications.orEmpty(),
    specializations = specializations.orEmpty().map(RepairEquipmentCategory::fromKey),
    brandsServiced = brandsServiced.orEmpty(),
    experienceYears = experienceYears ?: 0,
    serviceRadiusKm = serviceRadiusKm ?: 25,
    city = city?.takeIf { it.isNotBlank() },
    state = state?.takeIf { it.isNotBlank() },
    verificationStatus = VerificationStatus.fromKey(verificationStatus),
    verificationNotes = verificationNotes?.takeIf { it.isNotBlank() },
    rejectedDocTypes = rejectedDocTypes.orEmpty(),
    backgroundCheckStatus = VerificationStatus.fromKey(backgroundCheckStatus),
    certificates = certificates.orEmpty(),
    hourlyRate = hourlyRate,
    yearsExperience = yearsExperience,
    serviceAreas = serviceAreas.orEmpty(),
    bio = bio?.takeIf { it.isNotBlank() },
    isAvailable = isAvailable ?: true,
    latitude = latitude,
    longitude = longitude,
    ratingAvg = ratingAvg,
    totalJobs = totalJobs,
    completionRate = completionRate,
)
