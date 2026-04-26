package com.equipseva.app.core.data.buyerkyc

import com.equipseva.app.core.storage.StorageRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Singleton
class BuyerKycRepository @Inject constructor(
    private val client: SupabaseClient,
    private val storage: StorageRepository,
) {
    enum class DocType(val key: String, val display: String, val subtitle: String) {
        ShopRegistration("shop_registration", "Shop Registration", "Shops & Establishment certificate"),
        Gst("gst", "GST Number", "GSTIN + uploaded certificate"),
        DrugLicense("drug_license", "Drug License", "Form 20 / 21 — pharmacy license"),
        Mci("mci", "MCI", "Medical Council of India registration"),
        Dci("dci", "DCI", "Dental Council of India registration"),
        MedicalId("medical_id", "Medical ID", "Medical staff / student ID (non-personal use)"),
    }

    @Serializable
    data class Insertion(
        @SerialName("user_id") val userId: String,
        @SerialName("doc_type") val docType: String,
        @SerialName("doc_url") val docUrl: String,
        @SerialName("gst_number") val gstNumber: String? = null,
    )

    /**
     * Uploads [bytes] to the kyc-docs bucket under `{user_id}/buyer_kyc_{docType}.{ext}`,
     * then inserts a verification request row with status `pending`. Profile's
     * `buyer_kyc_status` flips to `pending` via the server-side trigger.
     */
    suspend fun submit(
        docType: DocType,
        bytes: ByteArray,
        mimeType: String,
        gstNumber: String? = null,
    ): Result<Unit> = runCatching {
        val uid = client.auth.currentUserOrNull()?.id
            ?: error("not_authenticated")
        if (docType == DocType.Gst && (gstNumber.isNullOrBlank() || gstNumber.length !in 10..20)) {
            error("gst_number_required")
        }
        val ext = when (mimeType.lowercase()) {
            "application/pdf" -> "pdf"
            "image/png" -> "png"
            "image/webp" -> "webp"
            else -> "jpg"
        }
        val path = "$uid/buyer_kyc_${docType.key}.$ext"
        storage.upload(StorageRepository.Buckets.KYC_DOCS, path, bytes, mimeType).getOrThrow()
        val docUrl = storage.signedUrl(StorageRepository.Buckets.KYC_DOCS, path, expiresInMinutes = 60 * 24 * 30)
        client.postgrest.from("buyer_kyc_verifications")
            .insert(
                Insertion(
                    userId = uid,
                    docType = docType.key,
                    docUrl = docUrl,
                    gstNumber = gstNumber?.takeIf { it.isNotBlank() }?.uppercase(),
                ),
            )
        Unit
    }
}
