package com.equipseva.app.core.data.location

/**
 * Bundled cascade of India administrative geography — State/UT → District →
 * (Telangana only) Mandal — used by the KYC service-area picker, both
 * onboarding flows and the address form. Country is fixed to India.
 *
 * What is actually bundled (measured 2026-09-23; pinned by
 * IndiaLocationsCatalogIntegrityTest, so this comment cannot drift again):
 *   - 36 States/UTs (28 states + 8 union territories).
 *   - A district list for EVERY State/UT — from 1 (Chandigarh, Lakshadweep)
 *     to 75 (Uttar Pradesh). The free-text district fallback in the
 *     onboarding forms is therefore reached only when the state value is
 *     not a member of [STATES] (legacy or corrupted data), not for whole
 *     states, as older comments here claimed.
 *   - Mandals for 14 Telangana districts only; other districts return an
 *     empty list and the UI hides the mandal step.
 *
 * Provenance and known staleness: names transcribed from the Local
 * Government Directory (lgdirectory.gov.in) at an unrecorded date — NAMES
 * ONLY, no LGD district codes — and uneven across States: Chhattisgarh
 * already carries its 2022 districts while Assam still lacks Bajali (2021)
 * and Tamulpur (2022). [KNOWN_MISSING] names the districts known to be
 * absent (pinned by IndiaLocationsCatalogIntegrityTest, so adding one forces
 * that list and this header to move); Rajasthan predates its 2023
 * reorganisation and Madhya Pradesh still carries Hoshangabad for
 * Narmadapuram. Historical spellings resolve through [IndiaRegionAliases]
 * instead of being rewritten here, because stored profile/engineer rows
 * reference the bundled spellings. PRODUCT_PLAN §6 (delivery-ledger P2.2)
 * replaces this with a reviewed, dated, coded LGD snapshot; until then the
 * lists are a picker convenience, never an authority decision. Persist
 * [CATALOG_VERSION] with any pick so the migration can tell which snapshot
 * a record was validated against. State/UT codes live in [IndiaStateCodes].
 */
object IndiaLocations {

    const val COUNTRY = "India"

    /**
     * Identifies the bundled snapshot a State/UT + district pick was validated
     * against. Bump when the lists change; persist next to any stored pick
     * (PRODUCT_PLAN §6: "persist official stable codes plus catalog version").
     * Deliberately carries no source year: the transcription date is not
     * recorded and the lists are uneven across States (see the header).
     */
    const val CATALOG_VERSION = "bundled-names-v1"

    /**
     * Districts known to exist officially but absent from the bundled lists,
     * by State/UT. Documentation as data: the integrity test asserts each is
     * really absent, so adding one to the lists forces this map (and the
     * header) to move with it. Not exhaustive — Rajasthan's 2023
     * reorganisation alone adds more than this.
     */
    val KNOWN_MISSING: Map<String, List<String>> = mapOf(
        "Arunachal Pradesh" to listOf("Bichom", "Keyi Panyor"),
        "Assam" to listOf("Bajali", "Tamulpur"),
        "Gujarat" to listOf("Vav-Tharad"),
        "Ladakh" to listOf("Changthang", "Drass", "Nubra", "Sham", "Zanskar"),
        "Madhya Pradesh" to listOf("Maihar", "Mauganj", "Pandhurna"),
        "Nagaland" to listOf("Meluri"),
    )

    /**
     * Maps a raw State/UT string — a stored profile value, a legacy
     * `engineers.city` tail or an Android Geocoder adminArea — to its
     * canonical [STATES] entry, or null if it cannot be matched.
     *
     * Resolution order, strictest first:
     *   1. exact match ignoring case/whitespace;
     *   2. match after [IndiaRegionAliases.normalize] ("Jammu & Kashmir",
     *      "tamil-nadu");
     *   3. explicit legacy alias ("Orissa", "Pondicherry", "NCT of Delhi",
     *      "Daman and Diu");
     *   4. Only when [allowEmbedded] (the default, for Geocoder prefill): a
     *      longer phrase that embeds a canonical name as whole words
     *      ("Karnataka, India", "New Delhi" → Delhi). It is never used to
     *      decide authority — it only pre-selects a dropdown the user still
     *      confirms. Pass `allowEmbedded = false` when reading stored or
     *      composed values, where the State/UT is always written in full and
     *      an embedded match would swallow a district name such as "New Delhi".
     *
     * Callers use this so a non-canonical value never fills the state field
     * (the dropdown only renders canonical members).
     */
    fun canonicalState(raw: String?, allowEmbedded: Boolean = true): String? {
        val t = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        STATES.firstOrNull { it.equals(t, ignoreCase = true) }?.let { return it }
        val key = IndiaRegionAliases.normalize(t)
        if (key.isEmpty()) return null
        STATES.firstOrNull { IndiaRegionAliases.normalize(it) == key }?.let { return it }
        IndiaRegionAliases.STATES[key]?.let { return it }
        if (!allowEmbedded) return null
        return embeddedState(key)
    }

    /**
     * Step 4 of [canonicalState]: whole-word containment on the normalized
     * text ("karnataka india" contains karnataka; "goalpara" does not contain
     * goa), with one precompiled pattern per State/UT. When a phrase embeds
     * several names ("Karnataka Colony, Hyderabad, Telangana") the rightmost
     * wins — Geocoder and address strings put the enclosing region last.
     */
    private val embeddedStatePatterns: Map<String, Regex> by lazy {
        STATES.associateWith { name -> wholeWord(IndiaRegionAliases.normalize(name)) }
    }

    private fun embeddedState(normalizedText: String): String? =
        embeddedStatePatterns.entries
            .mapNotNull { (name, regex) ->
                // Last occurrence, so a State named twice keeps its rightmost position.
                regex.findAll(normalizedText).lastOrNull()?.let { name to it.range.first }
            }
            .maxByOrNull { it.second }
            ?.first

    /** Prefill-only whole-word patterns for [canonicalDistrict], precompiled per State/UT on first use. */
    private val embeddedDistrictPatterns: Map<String, List<Pair<String, Regex>>> by lazy {
        STATES.associateWith { state ->
            districtsFor(state).map { district -> district to wholeWord(IndiaRegionAliases.normalize(district)) }
        }
    }

    /** Whole-word pattern over normalized (lower-case, punctuation-free) text. */
    private fun wholeWord(normalizedName: String): Regex =
        Regex("(?<!\\p{L})" + Regex.escape(normalizedName) + "(?!\\p{L})")

    /** All 28 states + 8 union territories, alphabetical. */
    val STATES: List<String> = listOf(
        // States
        "Andhra Pradesh",
        "Arunachal Pradesh",
        "Assam",
        "Bihar",
        "Chhattisgarh",
        "Goa",
        "Gujarat",
        "Haryana",
        "Himachal Pradesh",
        "Jharkhand",
        "Karnataka",
        "Kerala",
        "Madhya Pradesh",
        "Maharashtra",
        "Manipur",
        "Meghalaya",
        "Mizoram",
        "Nagaland",
        "Odisha",
        "Punjab",
        "Rajasthan",
        "Sikkim",
        "Tamil Nadu",
        "Telangana",
        "Tripura",
        "Uttar Pradesh",
        "Uttarakhand",
        "West Bengal",
        // Union Territories
        "Andaman and Nicobar Islands",
        "Chandigarh",
        "Dadra and Nagar Haveli and Daman and Diu",
        "Delhi",
        "Jammu and Kashmir",
        "Ladakh",
        "Lakshadweep",
        "Puducherry",
    )

    /**
     * Districts keyed by state. All 28 states + 8 UTs covered. Source:
     * Local Government Directory, current as of 2024.
     */
    private val DISTRICTS: Map<String, List<String>> = mapOf(
        "Andhra Pradesh" to listOf(
            "Alluri Sitharama Raju", "Anakapalli", "Anantapur", "Annamayya",
            "Bapatla", "Chittoor", "East Godavari", "Eluru", "Guntur",
            "Kakinada", "Konaseema", "Krishna", "Kurnool", "Nandyal",
            "Nellore", "NTR", "Palnadu", "Parvathipuram Manyam", "Prakasam",
            "Srikakulam", "Sri Sathya Sai", "Tirupati", "Visakhapatnam",
            "Vizianagaram", "West Godavari", "YSR Kadapa",
        ),
        "Arunachal Pradesh" to listOf(
            "Anjaw", "Changlang", "Dibang Valley", "East Kameng", "East Siang",
            "Kamle", "Kra Daadi", "Kurung Kumey", "Lepa Rada", "Lohit",
            "Longding", "Lower Dibang Valley", "Lower Siang", "Lower Subansiri",
            "Namsai", "Pakke Kessang", "Papum Pare", "Shi Yomi", "Siang",
            "Tawang", "Tirap", "Upper Siang", "Upper Subansiri", "West Kameng",
            "West Siang", "Itanagar Capital Complex",
        ),
        "Assam" to listOf(
            "Baksa", "Barpeta", "Biswanath", "Bongaigaon", "Cachar",
            "Charaideo", "Chirang", "Darrang", "Dhemaji", "Dhubri",
            "Dibrugarh", "Dima Hasao", "Goalpara", "Golaghat", "Hailakandi",
            "Hojai", "Jorhat", "Kamrup", "Kamrup Metropolitan", "Karbi Anglong",
            "Karimganj", "Kokrajhar", "Lakhimpur", "Majuli", "Morigaon",
            "Nagaon", "Nalbari", "Sivasagar", "Sonitpur", "South Salmara-Mankachar",
            "Tinsukia", "Udalguri", "West Karbi Anglong",
        ),
        "Bihar" to listOf(
            "Araria", "Arwal", "Aurangabad", "Banka", "Begusarai",
            "Bhagalpur", "Bhojpur", "Buxar", "Darbhanga", "East Champaran",
            "Gaya", "Gopalganj", "Jamui", "Jehanabad", "Kaimur",
            "Katihar", "Khagaria", "Kishanganj", "Lakhisarai", "Madhepura",
            "Madhubani", "Munger", "Muzaffarpur", "Nalanda", "Nawada",
            "Patna", "Purnia", "Rohtas", "Saharsa", "Samastipur",
            "Saran", "Sheikhpura", "Sheohar", "Sitamarhi", "Siwan",
            "Supaul", "Vaishali", "West Champaran",
        ),
        "Chhattisgarh" to listOf(
            "Balod", "Baloda Bazar", "Balrampur", "Bastar", "Bemetara",
            "Bijapur", "Bilaspur", "Dantewada", "Dhamtari", "Durg",
            "Gariaband", "Gaurela-Pendra-Marwahi", "Janjgir-Champa",
            "Jashpur", "Kabirdham", "Kanker", "Kondagaon", "Korba",
            "Koriya", "Mahasamund", "Mungeli", "Narayanpur", "Raigarh",
            "Raipur", "Rajnandgaon", "Sukma", "Surajpur", "Surguja",
            "Manendragarh-Chirmiri-Bharatpur", "Mohla-Manpur-Ambagarh Chowki",
            "Sarangarh-Bilaigarh", "Sakti", "Khairagarh-Chhuikhadan-Gandai",
        ),
        "Goa" to listOf("North Goa", "South Goa"),
        "Gujarat" to listOf(
            "Ahmedabad", "Amreli", "Anand", "Aravalli", "Banaskantha",
            "Bharuch", "Bhavnagar", "Botad", "Chhota Udaipur", "Dahod",
            "Dang", "Devbhoomi Dwarka", "Gandhinagar", "Gir Somnath",
            "Jamnagar", "Junagadh", "Kheda", "Kutch", "Mahisagar",
            "Mehsana", "Morbi", "Narmada", "Navsari", "Panchmahal",
            "Patan", "Porbandar", "Rajkot", "Sabarkantha", "Surat",
            "Surendranagar", "Tapi", "Vadodara", "Valsad",
        ),
        "Haryana" to listOf(
            "Ambala", "Bhiwani", "Charkhi Dadri", "Faridabad", "Fatehabad",
            "Gurugram", "Hisar", "Jhajjar", "Jind", "Kaithal",
            "Karnal", "Kurukshetra", "Mahendragarh", "Nuh", "Palwal",
            "Panchkula", "Panipat", "Rewari", "Rohtak", "Sirsa",
            "Sonipat", "Yamunanagar",
        ),
        "Himachal Pradesh" to listOf(
            "Bilaspur", "Chamba", "Hamirpur", "Kangra", "Kinnaur",
            "Kullu", "Lahaul and Spiti", "Mandi", "Shimla", "Sirmaur",
            "Solan", "Una",
        ),
        "Jharkhand" to listOf(
            "Bokaro", "Chatra", "Deoghar", "Dhanbad", "Dumka",
            "East Singhbhum", "Garhwa", "Giridih", "Godda", "Gumla",
            "Hazaribagh", "Jamtara", "Khunti", "Koderma", "Latehar",
            "Lohardaga", "Pakur", "Palamu", "Ramgarh", "Ranchi",
            "Sahebganj", "Saraikela Kharsawan", "Simdega", "West Singhbhum",
        ),
        "Karnataka" to listOf(
            "Bagalkot", "Ballari", "Belagavi", "Bengaluru Rural", "Bengaluru Urban",
            "Bidar", "Chamarajanagar", "Chikkaballapur", "Chikkamagaluru",
            "Chitradurga", "Dakshina Kannada", "Davangere", "Dharwad", "Gadag",
            "Hassan", "Haveri", "Kalaburagi", "Kodagu", "Kolar", "Koppal",
            "Mandya", "Mysuru", "Raichur", "Ramanagara", "Shivamogga",
            "Tumakuru", "Udupi", "Uttara Kannada", "Vijayanagara", "Vijayapura",
            "Yadgir",
        ),
        "Kerala" to listOf(
            "Alappuzha", "Ernakulam", "Idukki", "Kannur", "Kasaragod",
            "Kollam", "Kottayam", "Kozhikode", "Malappuram", "Palakkad",
            "Pathanamthitta", "Thiruvananthapuram", "Thrissur", "Wayanad",
        ),
        "Madhya Pradesh" to listOf(
            "Agar Malwa", "Alirajpur", "Anuppur", "Ashoknagar", "Balaghat",
            "Barwani", "Betul", "Bhind", "Bhopal", "Burhanpur",
            "Chhatarpur", "Chhindwara", "Damoh", "Datia", "Dewas",
            "Dhar", "Dindori", "Guna", "Gwalior", "Harda",
            "Hoshangabad", "Indore", "Jabalpur", "Jhabua", "Katni",
            "Khandwa", "Khargone", "Mandla", "Mandsaur", "Morena",
            "Narsinghpur", "Neemuch", "Niwari", "Panna", "Raisen",
            "Rajgarh", "Ratlam", "Rewa", "Sagar", "Satna",
            "Sehore", "Seoni", "Shahdol", "Shajapur", "Sheopur",
            "Shivpuri", "Sidhi", "Singrauli", "Tikamgarh", "Ujjain",
            "Umaria", "Vidisha",
        ),
        "Maharashtra" to listOf(
            "Ahmednagar", "Akola", "Amravati", "Chhatrapati Sambhaji Nagar",
            "Beed", "Bhandara", "Buldhana", "Chandrapur", "Dhule",
            "Gadchiroli", "Gondia", "Hingoli", "Jalgaon", "Jalna",
            "Kolhapur", "Latur", "Mumbai City", "Mumbai Suburban",
            "Nagpur", "Nanded", "Nandurbar", "Nashik", "Dharashiv",
            "Palghar", "Parbhani", "Pune", "Raigad", "Ratnagiri",
            "Sangli", "Satara", "Sindhudurg", "Solapur", "Thane",
            "Wardha", "Washim", "Yavatmal",
        ),
        "Manipur" to listOf(
            "Bishnupur", "Chandel", "Churachandpur", "Imphal East",
            "Imphal West", "Jiribam", "Kakching", "Kamjong", "Kangpokpi",
            "Noney", "Pherzawl", "Senapati", "Tamenglong", "Tengnoupal",
            "Thoubal", "Ukhrul",
        ),
        "Meghalaya" to listOf(
            "East Garo Hills", "East Jaintia Hills", "East Khasi Hills",
            "Eastern West Khasi Hills", "North Garo Hills", "Ri Bhoi",
            "South Garo Hills", "South West Garo Hills", "South West Khasi Hills",
            "West Garo Hills", "West Jaintia Hills", "West Khasi Hills",
        ),
        "Mizoram" to listOf(
            "Aizawl", "Champhai", "Hnahthial", "Khawzawl", "Kolasib",
            "Lawngtlai", "Lunglei", "Mamit", "Saiha", "Saitual",
            "Serchhip",
        ),
        "Nagaland" to listOf(
            "Chumukedima", "Dimapur", "Kiphire", "Kohima", "Longleng",
            "Mokokchung", "Mon", "Niuland", "Noklak", "Peren", "Phek",
            "Shamator", "Tseminyu", "Tuensang", "Wokha", "Zunheboto",
        ),
        "Odisha" to listOf(
            "Angul", "Balangir", "Balasore", "Bargarh", "Bhadrak",
            "Boudh", "Cuttack", "Debagarh", "Dhenkanal", "Gajapati",
            "Ganjam", "Jagatsinghpur", "Jajpur", "Jharsuguda", "Kalahandi",
            "Kandhamal", "Kendrapara", "Kendujhar", "Khordha", "Koraput",
            "Malkangiri", "Mayurbhanj", "Nabarangpur", "Nayagarh", "Nuapada",
            "Puri", "Rayagada", "Sambalpur", "Subarnapur", "Sundergarh",
        ),
        "Punjab" to listOf(
            "Amritsar", "Barnala", "Bathinda", "Faridkot", "Fatehgarh Sahib",
            "Fazilka", "Ferozepur", "Gurdaspur", "Hoshiarpur", "Jalandhar",
            "Kapurthala", "Ludhiana", "Malerkotla", "Mansa", "Moga",
            "Mohali", "Muktsar", "Pathankot", "Patiala", "Rupnagar",
            "Sangrur", "Shaheed Bhagat Singh Nagar", "Tarn Taran",
        ),
        "Rajasthan" to listOf(
            "Ajmer", "Alwar", "Banswara", "Baran", "Barmer",
            "Bharatpur", "Bhilwara", "Bikaner", "Bundi", "Chittorgarh",
            "Churu", "Dausa", "Dholpur", "Dungarpur", "Ganganagar",
            "Hanumangarh", "Jaipur", "Jaisalmer", "Jalore", "Jhalawar",
            "Jhunjhunu", "Jodhpur", "Karauli", "Kota", "Nagaur",
            "Pali", "Pratapgarh", "Rajsamand", "Sawai Madhopur", "Sikar",
            "Sirohi", "Tonk", "Udaipur",
        ),
        "Sikkim" to listOf("Gangtok", "Gyalshing", "Mangan", "Namchi", "Pakyong", "Soreng"),
        "Tamil Nadu" to listOf(
            "Ariyalur", "Chengalpattu", "Chennai", "Coimbatore", "Cuddalore",
            "Dharmapuri", "Dindigul", "Erode", "Kallakurichi", "Kancheepuram",
            "Kanyakumari", "Karur", "Krishnagiri", "Madurai", "Mayiladuthurai",
            "Nagapattinam", "Namakkal", "Nilgiris", "Perambalur", "Pudukkottai",
            "Ramanathapuram", "Ranipet", "Salem", "Sivagangai", "Tenkasi",
            "Thanjavur", "Theni", "Thiruvallur", "Thiruvarur", "Thoothukudi",
            "Tiruchirappalli", "Tirunelveli", "Tirupathur", "Tiruppur",
            "Tiruvannamalai", "Vellore", "Viluppuram", "Virudhunagar",
        ),
        "Telangana" to listOf(
            "Adilabad", "Bhadradri Kothagudem", "Hanumakonda", "Hyderabad",
            "Jagtial", "Jangaon", "Jayashankar Bhupalpally", "Jogulamba Gadwal",
            "Kamareddy", "Karimnagar", "Khammam", "Komaram Bheem Asifabad",
            "Mahabubabad", "Mahabubnagar", "Mancherial", "Medak",
            "Medchal-Malkajgiri", "Mulugu", "Nagarkurnool", "Nalgonda",
            "Narayanpet", "Nirmal", "Nizamabad", "Peddapalli",
            "Rajanna Sircilla", "Rangareddy", "Sangareddy", "Siddipet",
            "Suryapet", "Vikarabad", "Wanaparthy", "Warangal",
            "Yadadri Bhuvanagiri",
        ),
        "Tripura" to listOf(
            "Dhalai", "Gomati", "Khowai", "North Tripura", "Sepahijala",
            "South Tripura", "Unakoti", "West Tripura",
        ),
        "Uttar Pradesh" to listOf(
            "Agra", "Aligarh", "Ambedkar Nagar", "Amethi", "Amroha",
            "Auraiya", "Ayodhya", "Azamgarh", "Baghpat", "Bahraich",
            "Ballia", "Balrampur", "Banda", "Barabanki", "Bareilly",
            "Basti", "Bhadohi", "Bijnor", "Budaun", "Bulandshahr",
            "Chandauli", "Chitrakoot", "Deoria", "Etah", "Etawah",
            "Farrukhabad", "Fatehpur", "Firozabad", "Gautam Buddha Nagar",
            "Ghaziabad", "Ghazipur", "Gonda", "Gorakhpur", "Hamirpur",
            "Hapur", "Hardoi", "Hathras", "Jalaun", "Jaunpur",
            "Jhansi", "Kannauj", "Kanpur Dehat", "Kanpur Nagar",
            "Kasganj", "Kaushambi", "Kheri", "Kushinagar", "Lalitpur",
            "Lucknow", "Maharajganj", "Mahoba", "Mainpuri", "Mathura",
            "Mau", "Meerut", "Mirzapur", "Moradabad", "Muzaffarnagar",
            "Pilibhit", "Pratapgarh", "Prayagraj", "Raebareli", "Rampur",
            "Saharanpur", "Sambhal", "Sant Kabir Nagar", "Shahjahanpur",
            "Shamli", "Shrawasti", "Siddharthnagar", "Sitapur", "Sonbhadra",
            "Sultanpur", "Unnao", "Varanasi",
        ),
        "Uttarakhand" to listOf(
            "Almora", "Bageshwar", "Chamoli", "Champawat", "Dehradun",
            "Haridwar", "Nainital", "Pauri Garhwal", "Pithoragarh", "Rudraprayag",
            "Tehri Garhwal", "Udham Singh Nagar", "Uttarkashi",
        ),
        "West Bengal" to listOf(
            "Alipurduar", "Bankura", "Birbhum", "Cooch Behar", "Dakshin Dinajpur",
            "Darjeeling", "Hooghly", "Howrah", "Jalpaiguri", "Jhargram",
            "Kalimpong", "Kolkata", "Malda", "Murshidabad", "Nadia",
            "North 24 Parganas", "Paschim Bardhaman", "Paschim Medinipur",
            "Purba Bardhaman", "Purba Medinipur", "Purulia", "South 24 Parganas",
            "Uttar Dinajpur",
        ),
        "Andaman and Nicobar Islands" to listOf("Nicobar", "North and Middle Andaman", "South Andaman"),
        "Chandigarh" to listOf("Chandigarh"),
        "Dadra and Nagar Haveli and Daman and Diu" to listOf("Dadra and Nagar Haveli", "Daman", "Diu"),
        "Delhi" to listOf(
            "Central Delhi", "East Delhi", "New Delhi", "North Delhi",
            "North East Delhi", "North West Delhi", "Shahdara", "South Delhi",
            "South East Delhi", "South West Delhi", "West Delhi",
        ),
        "Jammu and Kashmir" to listOf(
            "Anantnag", "Bandipora", "Baramulla", "Budgam", "Doda",
            "Ganderbal", "Jammu", "Kathua", "Kishtwar", "Kulgam",
            "Kupwara", "Poonch", "Pulwama", "Rajouri", "Ramban",
            "Reasi", "Samba", "Shopian", "Srinagar", "Udhampur",
        ),
        "Ladakh" to listOf("Kargil", "Leh"),
        "Lakshadweep" to listOf("Lakshadweep"),
        "Puducherry" to listOf("Karaikal", "Mahe", "Puducherry", "Yanam"),
    )

    /**
     * Mandals (sub-districts / tehsils / talukas) keyed by "$state|$district".
     * Telangana coverage only for now. Empty list means UI should hide the
     * mandal field.
     */
    private val MANDALS: Map<String, List<String>> = mapOf(
        "Telangana|Hyderabad" to listOf(
            "Ameerpet", "Asifnagar", "Bahadurpura", "Bandlaguda", "Charminar",
            "Golconda", "Himayatnagar", "Khairatabad", "Marredpally",
            "Musheerabad", "Nampally", "Saidabad", "Secunderabad", "Shaikpet",
            "Tirumalagiri",
        ),
        "Telangana|Rangareddy" to listOf(
            "Abdullapurmet", "Balapur", "Chevella", "Gandipet", "Hayathnagar",
            "Ibrahimpatnam", "Kandukur", "Keesara", "Maheshwaram", "Manchal",
            "Moinabad", "Nandigama", "Pahadi Shareef", "Rajendranagar",
            "Saroornagar", "Serilingampally", "Shabad", "Shamshabad",
            "Shankarpalle", "Yacharam",
        ),
        "Telangana|Medchal-Malkajgiri" to listOf(
            "Alwal", "Bachupally", "Balanagar", "Dundigal", "Gajularamaram",
            "Ghatkesar", "Kapra", "Keesara", "Kukatpally", "Malkajgiri",
            "Medchal", "Medipalli", "Quthbullapur", "Shamirpet", "Uppal",
        ),
        "Telangana|Nalgonda" to listOf(
            "Adavidevulapally", "Anumula", "Chityal", "Chandampet", "Chandur",
            "Damaracherla", "Devarakonda", "Gundlapally", "Gurrampode",
            "Kanagal", "Kangal", "Kattangoor", "Kethepally", "Madugulapally",
            "Marriguda", "Miryalaguda", "Munugode", "Nakrekal", "Nalgonda",
            "Nampally", "Narayanpur", "Neredugommu", "Nidamanoor", "PA Pally",
            "Peddavoora", "Shaligouraram", "Thirumalagiri", "Thripuraram",
            "Tipparthy", "Vemulapally", "Yadagirigutta",
        ),
        "Telangana|Suryapet" to listOf(
            "Atmakur", "Chilkur", "Chivvemla", "Garidepally", "Huzurnagar",
            "Jajireddygudem", "Kodad", "Mattampally", "Mellachervu",
            "Mothey", "Munagala", "Nadigudem", "Nagaram", "Nereducherla",
            "Neredugommu", "Palakaveedu", "Penpahad", "Pillalamarri",
            "Suryapet", "Thirumalagiri", "Thungathurthi",
        ),
        "Telangana|Khammam" to listOf(
            "Bonakal", "Chinthakani", "Enkuru", "Kalluru", "Kamepalle",
            "Khammam Rural", "Khammam Urban", "Kusumanchi", "Madhira",
            "Mudigonda", "Nelakondapally", "Penuballi", "Raghunadhapalem",
            "Sathupally", "Singareni", "Tallada", "Thirumalayapalem",
            "Vemsoor", "Wyra", "Yerrupalem",
        ),
        "Telangana|Warangal" to listOf(
            "Atmakur", "Chennaraopet", "Damera", "Duggondi", "Khanapur",
            "Narsampet", "Nallabelly", "Nekkonda", "Parvathagiri",
            "Raiparthy", "Sangem", "Wardhannapet",
        ),
        "Telangana|Hanumakonda" to listOf(
            "Atmakur", "Bheemadevarapally", "Dharmasagar", "Hanamkonda",
            "Hasanparthy", "Inavolu", "Kazipet", "Velair",
        ),
        "Telangana|Karimnagar" to listOf(
            "Chigurumamidi", "Choppadandi", "Gangadhara", "Ganneruvaram",
            "Huzurabad", "Jammikunta", "Karimnagar Rural", "Karimnagar Urban",
            "Kothapalle", "Manakondur", "Ramadugu", "Saidapur", "Shankarapatnam",
            "Thimmapur", "V Saidapur", "Veenavanka",
        ),
        "Telangana|Mahabubnagar" to listOf(
            "Addakal", "Balanagar", "Bhoothpur", "CC Kunta", "Devarakadra",
            "Dhanwada", "Hanwada", "Jadcherla", "Koilkonda", "Mahabubnagar",
            "Midjil", "Moosapet", "Musapet", "Mahabubnagar Rural",
            "Naveen Hanwada", "Rajapur",
        ),
        "Telangana|Adilabad" to listOf(
            "Adilabad Rural", "Adilabad Urban", "Bazarhathnoor", "Bela",
            "Bheempoor", "Boath", "Gadiguda", "Ichoda", "Inderavelly",
            "Jainad", "Mavala", "Narnoor", "Neradigonda", "Sirikonda",
            "Talamadugu", "Tamsi", "Utnoor",
        ),
        "Telangana|Nizamabad" to listOf(
            "Armoor", "Balkonda", "Bheemgal", "Bodhan", "Dichpally",
            "Dharpally", "Donkeshwar", "Indalwai", "Jakranpally", "Kammarpally",
            "Mendora", "Mortad", "Mugpal", "Nandipet", "Navipet", "Nizamabad Rural",
            "Nizamabad Urban", "Pitlam", "Renjal", "Rudrur", "Sirkonda",
            "Sirikonda", "Velpur", "Yedpally",
        ),
        "Telangana|Sangareddy" to listOf(
            "Andole", "Gummadidala", "Hatnoora", "Jharasangam", "Jinnaram",
            "Kalher", "Kandi", "Kohir", "Kondapur", "Manoor", "Munipally",
            "Nyalkal", "Patancheru", "Pulkal", "Raikode", "Ramachandrapuram",
            "Sadasivpet", "Sangareddy", "Shankarampet", "Sirgapur",
            "Tekmal", "Wargal", "Zaheerabad",
        ),
        "Telangana|Medak" to listOf(
            "Alladurg", "Chegunta", "Chilipched", "Havelighanpur", "Kohir",
            "Kowdipally", "Kulcharam", "Manoharabad", "Medak", "Narsapur",
            "Papannapet", "Ramayampet", "Shankarampet A", "Shankarampet R",
            "Shivampet", "Tekmal", "Toopran", "Wargal", "Yeldurthy",
        ),
    )

    fun districtsFor(state: String?): List<String> =
        DISTRICTS[state.orEmpty()].orEmpty()

    /**
     * Maps a raw district string to its canonical entry within [state]
     * (resolved through [canonicalState] with the same [allowEmbedded]
     * setting), or null. Exact (case-insensitive) match first, then a match
     * after [IndiaRegionAliases.normalize] ("Medchal–Malkajgiri" → the
     * hyphenated catalog spelling), then the State/UT-scoped legacy alias
     * table ("Bangalore" → "Bengaluru Urban"; Maharashtra's "Aurangabad" →
     * "Chhatrapati Sambhaji Nagar" while Bihar's "Aurangabad" stays itself).
     *
     * Strict by default: an unknown name returns null so the caller can show
     * it as needing confirmation. Geocoder prefill callers pass
     * `allowEmbedded = true` to also accept a phrase that embeds the district
     * as whole words ("Hyderabad District"; the longest embedded name wins,
     * so "North West Delhi district" is not read as West Delhi). That step
     * pre-selects a dropdown the user still confirms; it never decides
     * authority.
     */
    fun canonicalDistrict(state: String?, raw: String?, allowEmbedded: Boolean = false): String? {
        val st = canonicalState(state, allowEmbedded) ?: return null
        val t = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val districts = districtsFor(st)
        districts.firstOrNull { it.equals(t, ignoreCase = true) }?.let { return it }
        val key = IndiaRegionAliases.normalize(t)
        if (key.isEmpty()) return null
        districts.firstOrNull { IndiaRegionAliases.normalize(it) == key }?.let { return it }
        IndiaRegionAliases.DISTRICTS[st]?.get(key)?.let { return it }
        if (!allowEmbedded) return null
        return embeddedDistrictPatterns[st].orEmpty()
            .mapNotNull { (district, regex) -> regex.find(key)?.let { district to it.value.length } }
            .maxByOrNull { it.second }
            ?.first
    }

    fun mandalsFor(state: String?, district: String?): List<String> {
        if (state.isNullOrBlank() || district.isNullOrBlank()) return emptyList()
        return MANDALS["$state|$district"].orEmpty()
    }

    /**
     * Compose the picker output into the legacy single-string format the
     * backend stores in `engineers.city`. Empty parts are dropped.
     */
    fun compose(state: String?, district: String?, mandal: String?): String =
        listOfNotNull(
            mandal?.takeIf { it.isNotBlank() },
            district?.takeIf { it.isNotBlank() },
            state?.takeIf { it.isNotBlank() },
        ).joinToString(", ")
}
