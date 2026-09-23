package com.equipseva.app.core.data.location

/**
 * Official Local Government Directory (LGD) State/UT codes for the bundled
 * [IndiaLocations] catalog.
 *
 * PRODUCT_PLAN §6 (delivery-ledger row P2.2) requires records to persist a
 * stable official code plus a catalog version rather than a bare name. This
 * is the State/UT layer of that contract. **District codes are not bundled
 * yet** — they arrive with the reviewed, dated LGD district import — so
 * callers must not invent or derive them here.
 *
 * Provenance: LGD state codes coincide with the Census 2011 state codes
 * (01 Jammu and Kashmir … 35 Andaman and Nicobar Islands). LGD later
 * assigned 36 (Telangana, 2014), 37 (Ladakh, 2019) and 38 (the merged
 * Dadra and Nagar Haveli and Daman and Diu, 2020). The retired codes 25
 * (Daman and Diu) and 26 (Dadra and Nagar Haveli) are deliberately absent.
 * "Daman and Diu" resolves to the merged UT through [IndiaLocations.canonicalState];
 * "Dadra and Nagar Haveli" does not, because it is also a live district of the
 * merged UT — it resolves through [IndiaLocations.canonicalDistrict] instead, so
 * `lgdCode("Dadra and Nagar Haveli")` is null by design.
 */
object IndiaStateCodes {

    /** Human-readable provenance to store alongside a persisted pick. */
    const val SOURCE: String =
        "LGD State/UT codes (lgdirectory.gov.in), Census-2011 numbering plus 36-38; district codes pending import"

    /** Canonical [IndiaLocations.STATES] name → LGD state code. */
    val LGD: Map<String, Int> = mapOf(
        "Jammu and Kashmir" to 1,
        "Himachal Pradesh" to 2,
        "Punjab" to 3,
        "Chandigarh" to 4,
        "Uttarakhand" to 5,
        "Haryana" to 6,
        "Delhi" to 7,
        "Rajasthan" to 8,
        "Uttar Pradesh" to 9,
        "Bihar" to 10,
        "Sikkim" to 11,
        "Arunachal Pradesh" to 12,
        "Nagaland" to 13,
        "Manipur" to 14,
        "Mizoram" to 15,
        "Tripura" to 16,
        "Meghalaya" to 17,
        "Assam" to 18,
        "West Bengal" to 19,
        "Jharkhand" to 20,
        "Odisha" to 21,
        "Chhattisgarh" to 22,
        "Madhya Pradesh" to 23,
        "Gujarat" to 24,
        "Maharashtra" to 27,
        "Andhra Pradesh" to 28,
        "Karnataka" to 29,
        "Goa" to 30,
        "Lakshadweep" to 31,
        "Kerala" to 32,
        "Tamil Nadu" to 33,
        "Puducherry" to 34,
        "Andaman and Nicobar Islands" to 35,
        "Telangana" to 36,
        "Ladakh" to 37,
        "Dadra and Nagar Haveli and Daman and Diu" to 38,
    )

    /** The eight Union Territories in the catalog (everything else in [LGD] is a State). */
    val UNION_TERRITORIES: Set<String> = setOf(
        "Andaman and Nicobar Islands",
        "Chandigarh",
        "Dadra and Nagar Haveli and Daman and Diu",
        "Delhi",
        "Jammu and Kashmir",
        "Ladakh",
        "Lakshadweep",
        "Puducherry",
    )

    private val byCode: Map<Int, String> = LGD.entries.associate { (name, code) -> code to name }

    /**
     * LGD code for a State/UT given in any form [IndiaLocations.canonicalState]
     * resolves strictly ("Orissa", "Jammu & Kashmir", "telangana"); null when
     * the value cannot be resolved to a canonical entry. Strict by default
     * because this is the persisted authority code: the embedded-phrase
     * Geocoder step only runs when a prefill caller passes
     * `allowEmbedded = true` (PRODUCT_PLAN §6: no fuzzy matching is an
     * authority decision).
     */
    fun lgdCode(state: String?, allowEmbedded: Boolean = false): Int? =
        IndiaLocations.canonicalState(state, allowEmbedded)?.let { LGD[it] }

    /** Canonical State/UT name for an LGD code, or null for an unknown/retired code. */
    fun stateForCode(code: Int?): String? = code?.let { byCode[it] }

    /** Strict by default, like [lgdCode]. */
    fun isUnionTerritory(state: String?, allowEmbedded: Boolean = false): Boolean =
        IndiaLocations.canonicalState(state, allowEmbedded)?.let { it in UNION_TERRITORIES } ?: false
}
