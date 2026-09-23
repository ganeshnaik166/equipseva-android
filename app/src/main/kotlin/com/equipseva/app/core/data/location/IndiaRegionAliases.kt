package com.equipseva.app.core.data.location

import java.util.Locale

/**
 * Legacy-name and spelling aliases for the bundled [IndiaLocations] catalog.
 *
 * Why: profile rows, `engineers.city` strings and reverse-geocoder results
 * carry names that predate the catalog's spellings — "Orissa", "Bangalore",
 * "Ranga Reddy", Maharashtra's "Aurangabad" — and PRODUCT_PLAN §6 requires
 * such values to stay readable and to resolve through explicit alias history,
 * never through substring guessing. Every alias maps to a name that exists in
 * the catalog; `IndiaRegionAliasesTest` enforces that, so a typo cannot ship.
 *
 * Keys are the [normalize]d form (lower-case, `&` → "and", dashes and
 * punctuation → spaces, single spaces). District aliases are scoped to a
 * State/UT because the same historical name can be a live district elsewhere:
 * Aurangabad is still a Bihar district while Maharashtra's became
 * Chhatrapati Sambhaji Nagar.
 *
 * City-to-district entries are limited to cities that lie wholly within one
 * district (Guwahati → Kamrup Metropolitan, Noida → Gautam Buddha Nagar).
 * Anything that straddles or could mean several — "Bombay" (two Mumbai
 * districts), "Delhi" (eleven), "Burdwan" (split in 2017), "Secunderabad"
 * (Hyderabad and Medchal-Malkajgiri) — is deliberately left out so it
 * surfaces as needing confirmation instead of a silent pick. Two entries run
 * in reverse (current official name → the older spelling the bundled list
 * still carries): Narmadapuram → Hoshangabad and Ahilyanagar → Ahmednagar;
 * both flip when the coded LGD import lands.
 */
internal object IndiaRegionAliases {

    /** Canonical comparison form for catalog names and user/legacy input. */
    fun normalize(raw: String): String =
        raw.lowercase(Locale.ROOT)
            .replace("&", " and ")
            .replace(PUNCTUATION, " ")
            .replace(WHITESPACE, " ")
            .trim()

    // Hyphen, en dash, em dash, full stop, comma, straight and curly apostrophe,
    // parentheses, slash — all read as word separators.
    private val PUNCTUATION = Regex("[\\-–—.,'’()/]")
    private val WHITESPACE = Regex("\\s+")

    /** Historical, abbreviated or variant State/UT names → canonical [IndiaLocations.STATES] entry. */
    val STATES: Map<String, String> = mapOf(
        "orissa" to "Odisha",
        "pondicherry" to "Puducherry",
        "pondichery" to "Puducherry",
        "uttaranchal" to "Uttarakhand",
        "j and k" to "Jammu and Kashmir",
        "jammu kashmir" to "Jammu and Kashmir",
        "nct of delhi" to "Delhi",
        "national capital territory of delhi" to "Delhi",
        // "New Delhi" is deliberately NOT a state alias: it is a live district
        // of Delhi, so a lone "New Delhi" must resolve as district-with-
        // inferred-state (needs confirmation), not silently as the UT.
        "daman and diu" to "Dadra and Nagar Haveli and Daman and Diu",
        // "Dadra and Nagar Haveli" (the retired UT, code 26) is deliberately
        // NOT a state alias: it is a live district of the merged UT, so a lone
        // value resolves as district-with-inferred-UT and asks for confirmation.
        "dnh and dd" to "Dadra and Nagar Haveli and Daman and Diu",
        "andaman and nicobar" to "Andaman and Nicobar Islands",
        "a and n islands" to "Andaman and Nicobar Islands",
        "tamilnadu" to "Tamil Nadu",
        "chattisgarh" to "Chhattisgarh",
        "chhatisgarh" to "Chhattisgarh",
        "telangana state" to "Telangana",
        "andhra" to "Andhra Pradesh",
        "bengal" to "West Bengal",
        "himachal" to "Himachal Pradesh",
        "arunachal" to "Arunachal Pradesh",
    )

    /** State/UT → (normalized legacy district name → canonical district in that State/UT). */
    val DISTRICTS: Map<String, Map<String, String>> = mapOf(
        "Andhra Pradesh" to mapOf(
            "cuddapah" to "YSR Kadapa",
            "kadapa" to "YSR Kadapa",
            "ysr" to "YSR Kadapa",
            "y s r kadapa" to "YSR Kadapa",
            "vizag" to "Visakhapatnam",
            "vijayawada" to "NTR",
            "spsr nellore" to "Nellore",
            "sri potti sriramulu nellore" to "Nellore",
            "ananthapuramu" to "Anantapur",
            "anantapuramu" to "Anantapur",
            "nandyala" to "Nandyal",
        ),
        "Arunachal Pradesh" to mapOf(
            "itanagar" to "Itanagar Capital Complex",
        ),
        "Assam" to mapOf(
            "guwahati" to "Kamrup Metropolitan",
            "kamrup metro" to "Kamrup Metropolitan",
        ),
        "Goa" to mapOf(
            "panaji" to "North Goa",
            "panjim" to "North Goa",
            "margao" to "South Goa",
        ),
        "Gujarat" to mapOf(
            "baroda" to "Vadodara",
            "amdavad" to "Ahmedabad",
            "ahmadabad" to "Ahmedabad",
        ),
        "Haryana" to mapOf(
            "gurgaon" to "Gurugram",
        ),
        "Himachal Pradesh" to mapOf(
            "simla" to "Shimla",
        ),
        "Karnataka" to mapOf(
            "bangalore" to "Bengaluru Urban",
            "bangalore urban" to "Bengaluru Urban",
            "bengaluru" to "Bengaluru Urban",
            "bangalore rural" to "Bengaluru Rural",
            "mysore" to "Mysuru",
            "belgaum" to "Belagavi",
            "shimoga" to "Shivamogga",
            "bellary" to "Ballari",
            "tumkur" to "Tumakuru",
            "gulbarga" to "Kalaburagi",
            "bijapur" to "Vijayapura",
            "chikmagalur" to "Chikkamagaluru",
            "hubli" to "Dharwad",
            "hubballi" to "Dharwad",
            "hubli dharwad" to "Dharwad",
            "mangalore" to "Dakshina Kannada",
            "mangaluru" to "Dakshina Kannada",
        ),
        "Kerala" to mapOf(
            "trivandrum" to "Thiruvananthapuram",
            "cochin" to "Ernakulam",
            "kochi" to "Ernakulam",
            "calicut" to "Kozhikode",
            "trichur" to "Thrissur",
            "quilon" to "Kollam",
            "alleppey" to "Alappuzha",
            "palghat" to "Palakkad",
            "cannanore" to "Kannur",
        ),
        "Madhya Pradesh" to mapOf(
            // Renamed in 2022; the bundled 2024 name list still carries the
            // old spelling, so the current official name maps onto it until
            // the coded LGD import lands.
            "narmadapuram" to "Hoshangabad",
        ),
        "Maharashtra" to mapOf(
            "aurangabad" to "Chhatrapati Sambhaji Nagar",
            "chhatrapati sambhajinagar" to "Chhatrapati Sambhaji Nagar",
            "sambhajinagar" to "Chhatrapati Sambhaji Nagar",
            "osmanabad" to "Dharashiv",
            "poona" to "Pune",
            "nasik" to "Nashik",
            "ahmadnagar" to "Ahmednagar",
            "ahilyanagar" to "Ahmednagar",
        ),
        "Meghalaya" to mapOf(
            "shillong" to "East Khasi Hills",
        ),
        "Odisha" to mapOf(
            "bhubaneswar" to "Khordha",
            "khurda" to "Khordha",
            "berhampur" to "Ganjam",
        ),
        "Punjab" to mapOf(
            "jullundur" to "Jalandhar",
        ),
        "Tamil Nadu" to mapOf(
            "madras" to "Chennai",
            "tuticorin" to "Thoothukudi",
            "tanjore" to "Thanjavur",
            "trichy" to "Tiruchirappalli",
            "tiruchirapalli" to "Tiruchirappalli",
            "kanniyakumari" to "Kanyakumari",
        ),
        "Telangana" to mapOf(
            "ranga reddy" to "Rangareddy",
            "rangareddi" to "Rangareddy",
            "medchal" to "Medchal-Malkajgiri",
            "hanamkonda" to "Hanumakonda",
            "warangal urban" to "Hanumakonda",
            "warangal rural" to "Warangal",
            "mahbubnagar" to "Mahabubnagar",
            // No "secunderabad": it straddles Hyderabad and Medchal-Malkajgiri
            // (it remains reachable as a Hyderabad mandal).
            "bhuvanagiri" to "Yadadri Bhuvanagiri",
            "yadadri" to "Yadadri Bhuvanagiri",
            "gadwal" to "Jogulamba Gadwal",
            "kothagudem" to "Bhadradri Kothagudem",
            "bhupalpally" to "Jayashankar Bhupalpally",
            "sircilla" to "Rajanna Sircilla",
            "asifabad" to "Komaram Bheem Asifabad",
        ),
        "Tripura" to mapOf(
            "agartala" to "West Tripura",
        ),
        "Uttar Pradesh" to mapOf(
            "allahabad" to "Prayagraj",
            "faizabad" to "Ayodhya",
            "kanpur" to "Kanpur Nagar",
            "noida" to "Gautam Buddha Nagar",
            "greater noida" to "Gautam Buddha Nagar",
            "benares" to "Varanasi",
            "banaras" to "Varanasi",
        ),
        "West Bengal" to mapOf(
            "calcutta" to "Kolkata",
        ),
    )
}
