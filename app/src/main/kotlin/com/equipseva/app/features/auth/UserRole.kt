package com.equipseva.app.features.auth

/**
 * User-facing roles selectable in the app. `admin` is intentionally excluded — admin
 * accounts are provisioned via the web admin console only (locked decision: MFA
 * mandatory for admin role; mobile app does not expose admin onboarding).
 */
enum class UserRole(val storageKey: String, val displayName: String, val description: String) {
    // storageKey values mirror the server `user_role` enum verbatim.
    // `hospital_admin` is the server name even though we surface it as "Hospital buyer".
    HOSPITAL("hospital_admin", "Hospital buyer", "Buy parts, request repairs, manage equipment"),
    ENGINEER("engineer", "Field engineer", "Pick up jobs, bid, complete repairs"),
    SUPPLIER("supplier", "Parts supplier", "List parts and fulfil orders"),
    MANUFACTURER("manufacturer", "Manufacturer", "Receive RFQs and respond to leads"),
    LOGISTICS("logistics", "Logistics partner", "Pick up and deliver shipments");

    companion object {
        fun fromKey(key: String?): UserRole? = entries.firstOrNull { it.storageKey == key }
    }
}
