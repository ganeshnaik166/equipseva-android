package com.medeq.app.data.remote

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * Minimal Moshi models for the OpenFDA Device UDI endpoint:
 * https://api.fda.gov/device/udi.json?search=...
 *
 * Only the fields we actually use are typed; the rest are ignored.
 */
@JsonClass(generateAdapter = true)
data class OpenFdaUdiResponse(
    val meta: Meta?,
    val results: List<UdiResult> = emptyList(),
) {
    @JsonClass(generateAdapter = true)
    data class Meta(
        val results: ResultsMeta?,
    ) {
        @JsonClass(generateAdapter = true)
        data class ResultsMeta(val total: Int = 0)
    }
}

@JsonClass(generateAdapter = true)
data class UdiResult(
    @Json(name = "public_device_record_key") val recordKey: String?,
    @Json(name = "public_version_number")    val publicVersionNumber: String?,
    @Json(name = "public_version_date")      val publicVersionDate: String?,
    @Json(name = "device_publish_date")      val devicePublishDate: String?,
    @Json(name = "company_name")             val companyName: String?,
    @Json(name = "brand_name")               val brandName: String?,
    @Json(name = "version_or_model_number")  val versionOrModelNumber: String?,
    @Json(name = "catalog_number")           val catalogNumber: String?,
    @Json(name = "device_description")       val deviceDescription: String?,
    @Json(name = "is_rx")                    val isRx: Boolean?,
    @Json(name = "is_otc")                   val isOtc: Boolean?,
    @Json(name = "mri_safety")               val mriSafety: String?,
    @Json(name = "identifiers")              val identifiers: List<Identifier> = emptyList(),
    @Json(name = "gmdn_terms")               val gmdnTerms: List<GmdnTerm> = emptyList(),
) {
    @JsonClass(generateAdapter = true)
    data class Identifier(
        val id: String?,
        val type: String?,
        @Json(name = "issuing_agency") val issuingAgency: String?,
    )

    @JsonClass(generateAdapter = true)
    data class GmdnTerm(
        val name: String?,
        val definition: String?,
        @Json(name = "code") val code: String?,
    )
}
