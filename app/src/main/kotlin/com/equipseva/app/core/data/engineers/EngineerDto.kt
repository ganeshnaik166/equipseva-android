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
)
