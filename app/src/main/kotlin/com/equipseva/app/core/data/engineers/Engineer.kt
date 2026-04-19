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
    val backgroundCheckStatus: VerificationStatus,
    val certificates: List<EngineerCertificate>,
) {
    val aadhaarDocPath: String? get() =
        certificates.lastOrNull { it.type == EngineerCertificate.TYPE_AADHAAR }?.path

    val certDocPaths: List<String> get() =
        certificates.filter { it.type == EngineerCertificate.TYPE_CERT }.map { it.path }
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
    backgroundCheckStatus = VerificationStatus.fromKey(backgroundCheckStatus),
    certificates = certificates.orEmpty(),
)
