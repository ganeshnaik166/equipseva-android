package com.equipseva.app.core.data.location

/**
 * Result of reading a legacy composed location string such as the
 * `engineers.city` value written by [IndiaLocations.compose]
 * ("Mandal, District, State", with empty parts dropped).
 *
 * PRODUCT_PLAN §6: during the region migration a legacy free-text value must
 * remain visible and "needs confirmation" rather than being silently erased
 * or silently mapped into an arbitrary district. This type carries exactly
 * that distinction:
 *
 * - [state] / [district] / [mandal] are canonical catalog names when the
 *   text resolved, else null.
 * - [needsConfirmation] is true when anything was inferred rather than
 *   stated (a lone district name whose State/UT was worked out because it is
 *   unique nationwide) or when a part matched nothing ([unresolved]).
 * - [stateCandidates] lists the States/UTs that contain a district of the
 *   given name when the text named no State/UT and the name is not unique
 *   ("Bilaspur" → Chhattisgarh, Himachal Pradesh). The UI must ask; the
 *   parser never picks one.
 */
data class LegacyCityParse(
    val state: String?,
    val district: String?,
    val mandal: String?,
    val unresolved: List<String>,
    val stateCandidates: List<String>,
    val needsConfirmation: Boolean,
) {
    /** Nothing to read: blank input. Distinct from "read but unresolved". */
    val isEmpty: Boolean
        get() = state == null && district == null && mandal == null && unresolved.isEmpty()

    /** State/UT and district both resolved — the minimum a district-based flow needs. */
    val isComplete: Boolean
        get() = state != null && district != null

    companion object {
        val EMPTY = LegacyCityParse(
            state = null,
            district = null,
            mandal = null,
            unresolved = emptyList(),
            stateCandidates = emptyList(),
            needsConfirmation = false,
        )
    }
}

/**
 * Parse a legacy composed location string back into catalog names. Reads
 * from the right: the last part is tried as a State/UT, the next as a
 * district of that State/UT, the next as a Telangana mandal. Matching is
 * exact after [IndiaRegionAliases.normalize] plus the explicit alias tables —
 * never a substring guess.
 */
fun parseLegacyCity(raw: String?): LegacyCityParse {
    val parts = raw.orEmpty().split(',').map { it.trim() }.filter { it.isNotEmpty() }
    if (parts.isEmpty()) return LegacyCityParse.EMPTY

    val unresolved = mutableListOf<String>()
    var inferred = false
    var stateCandidates: List<String> = emptyList()
    var remaining = parts

    // Strict: compose() always writes the State/UT in full, so the embedded-
    // phrase Geocoder step must not run here — it would read the district
    // "New Delhi" as the UT and drop the district.
    var state: String? = IndiaLocations.canonicalState(remaining.last(), allowEmbedded = false)
    if (state != null) remaining = remaining.dropLast(1)

    var district: String? = null
    if (remaining.isNotEmpty()) {
        val candidate = remaining.last()
        if (state != null) {
            district = IndiaLocations.canonicalDistrict(state, candidate)
            if (district == null) unresolved += candidate
        } else {
            val homes = IndiaLocations.STATES.filter { IndiaLocations.canonicalDistrict(it, candidate) != null }
            when (homes.size) {
                1 -> {
                    state = homes.single()
                    district = IndiaLocations.canonicalDistrict(state, candidate)
                    inferred = true
                }
                0 -> unresolved += candidate
                else -> {
                    stateCandidates = homes
                    unresolved += candidate
                }
            }
        }
        remaining = remaining.dropLast(1)
    }

    var mandal: String? = null
    if (remaining.isNotEmpty()) {
        val candidate = remaining.last()
        mandal = if (state != null && district != null) {
            val key = IndiaRegionAliases.normalize(candidate)
            IndiaLocations.mandalsFor(state, district).firstOrNull { IndiaRegionAliases.normalize(it) == key }
        } else {
            null
        }
        if (mandal == null) unresolved += candidate
        remaining = remaining.dropLast(1)
    }
    // Anything further left is not part of the Mandal/District/State shape.
    unresolved += remaining

    return LegacyCityParse(
        state = state,
        district = district,
        mandal = mandal,
        unresolved = unresolved.toList(),
        stateCandidates = stateCandidates,
        needsConfirmation = inferred || unresolved.isNotEmpty(),
    )
}
