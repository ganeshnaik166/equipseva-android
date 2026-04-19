package com.equipseva.app.core.data.engineers

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * One uploaded KYC document, stored in `engineers.certificates` jsonb.
 * `type` discriminates between the single Aadhaar photo and self-supplied
 * training certificates so the KYC screen can rehydrate both slots on return.
 */
@Serializable
data class EngineerCertificate(
    val type: String,
    val path: String,
    @SerialName("uploaded_at") val uploadedAt: String,
) {
    companion object {
        const val TYPE_AADHAAR = "aadhaar"
        const val TYPE_CERT = "cert"
    }
}
