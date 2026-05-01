package com.equipseva.app.core.data.location

/**
 * Bundled cascade of India administrative geography for the KYC service-area
 * picker and any address form that needs structured input. Country is fixed
 * to India; the cascade is State → District → Mandal (Tehsil/Taluka).
 *
 * Coverage today is intentionally narrow:
 *   - All 28 states + 8 union territories as the State list.
 *   - Districts hard-coded for Telangana (active market) + a curated sample
 *     for adjacent / high-traffic states. Other states return an empty
 *     district list, in which case the UI falls back to a free-text District
 *     input so the user can still progress.
 *   - Mandals only for Telangana districts. Other districts return empty
 *     and the UI hides the Mandal step.
 *
 * Data source: Local Government Directory (lgdirectory.gov.in) +
 * data.gov.in. Update by replacing the maps below with a richer asset (e.g.
 * a bundled JSON in `assets/india_locations.json` and a parser) when the
 * full ~6,000 mandal dataset lands.
 */
object IndiaLocations {

    const val COUNTRY = "India"

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
