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
)

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
)
