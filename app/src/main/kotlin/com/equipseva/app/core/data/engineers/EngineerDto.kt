package com.equipseva.app.core.data.engineers

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class EngineerDto(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("aadhaar_number") val aadhaarNumber: String? = null,
    @SerialName("aadhaar_verified") val aadhaarVerified: Boolean? = null,
    val qualifications: List<String>? = null,
    val specializations: List<String>? = null,
    @SerialName("brands_serviced") val brandsServiced: List<String>? = null,
    @SerialName("experience_years") val experienceYears: Int? = null,
    @SerialName("service_radius_km") val serviceRadiusKm: Int? = null,
    val city: String? = null,
    val state: String? = null,
    @SerialName("verification_status") val verificationStatus: String? = null,
    @SerialName("background_check_status") val backgroundCheckStatus: String? = null,
    val certificates: List<EngineerCertificate>? = null,
    // Engineer-profile fields (separate from KYC). Nullable for back-compat with rows
    // that pre-date these columns; coerceInputValues=true on the Supabase Json keeps
    // missing keys safe.
    @SerialName("hourly_rate") val hourlyRate: Double? = null,
    @SerialName("years_experience") val yearsExperience: Int? = null,
    @SerialName("service_areas") val serviceAreas: List<String>? = null,
    val bio: String? = null,
    @SerialName("is_available") val isAvailable: Boolean? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
internal data class EngineerUpsertDto(
    @SerialName("user_id") val userId: String,
    @SerialName("aadhaar_number") val aadhaarNumber: String? = null,
    val qualifications: List<String>? = null,
    val specializations: List<String>? = null,
    @SerialName("experience_years") val experienceYears: Int? = null,
    @SerialName("service_radius_km") val serviceRadiusKm: Int? = null,
    val city: String? = null,
    val state: String? = null,
    val certificates: List<EngineerCertificate>? = null,
    // Only serialized when re-submitting after rejection so we don't clobber an
    // already-verified row back to pending.
    @SerialName("verification_status") val verificationStatus: String? = null,
)

/**
 * Payload for the engineer self-profile (rate / years / areas / specializations / bio).
 * Distinct from [EngineerUpsertDto] so the KYC screen and the profile screen don't
 * stomp each other's columns when only one set of fields is being edited.
 */
@Serializable
internal data class EngineerProfileUpsertDto(
    @SerialName("user_id") val userId: String,
    @SerialName("hourly_rate") val hourlyRate: Double,
    @SerialName("years_experience") val yearsExperience: Int,
    @SerialName("service_areas") val serviceAreas: List<String>,
    val specializations: List<String>,
    val bio: String,
    @SerialName("is_available") val isAvailable: Boolean,
)
