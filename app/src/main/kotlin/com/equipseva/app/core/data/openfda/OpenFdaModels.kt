package com.equipseva.app.core.data.openfda

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Minimal kotlinx.serialization models for the OpenFDA Device UDI endpoint:
 *   https://api.fda.gov/device/udi.json?search=...
 *
 * Only the fields we surface in the catalogue UI are typed; the full response
 * has dozens of additional medical-regulatory fields we skip via
 * `ignoreUnknownKeys = true` in the global Json provider.
 */
@Serializable
data class OpenFdaUdiResponse(
    val meta: Meta? = null,
    val results: List<UdiResult> = emptyList(),
) {
    @Serializable
    data class Meta(val results: ResultsMeta? = null) {
        @Serializable
        data class ResultsMeta(val total: Int = 0)
    }
}

@Serializable
data class UdiResult(
    @SerialName("public_device_record_key") val recordKey: String? = null,
    @SerialName("public_version_number")    val publicVersionNumber: String? = null,
    @SerialName("public_version_date")      val publicVersionDate: String? = null,
    @SerialName("device_publish_date")      val devicePublishDate: String? = null,
    @SerialName("company_name")             val companyName: String? = null,
    @SerialName("brand_name")               val brandName: String? = null,
    @SerialName("version_or_model_number")  val versionOrModelNumber: String? = null,
    @SerialName("catalog_number")           val catalogNumber: String? = null,
    @SerialName("device_description")       val deviceDescription: String? = null,
    @SerialName("is_rx")                    val isRx: Boolean? = null,
    @SerialName("is_otc")                   val isOtc: Boolean? = null,
    @SerialName("mri_safety")               val mriSafety: String? = null,
    @SerialName("identifiers")              val identifiers: List<Identifier> = emptyList(),
    @SerialName("gmdn_terms")               val gmdnTerms: List<GmdnTerm> = emptyList(),
) {
    @Serializable
    data class Identifier(
        val id: String? = null,
        val type: String? = null,
        @SerialName("issuing_agency") val issuingAgency: String? = null,
    )

    @Serializable
    data class GmdnTerm(
        val name: String? = null,
        val definition: String? = null,
        val code: String? = null,
    )
}
