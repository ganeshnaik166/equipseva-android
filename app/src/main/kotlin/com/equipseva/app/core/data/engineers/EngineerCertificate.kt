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
        // Face capture taken during KYC stepper Step 3. Server-side liveness
        // is deferred to v1.1 (IDfy / HyperVerge); for now this is just a
        // human-reviewed photo so admin can match against the Aadhaar.
        const val TYPE_SELFIE = "selfie"
        // PAN card photo. The 10-char PAN number itself lives on
        // engineers.pan_number; this jsonb entry only carries the doc path.
        const val TYPE_PAN = "pan"
    }
}
