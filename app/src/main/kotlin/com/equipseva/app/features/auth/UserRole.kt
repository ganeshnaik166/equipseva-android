package com.equipseva.app.features.auth

/**
 * User-facing roles selectable in the app. `admin` is intentionally excluded — admin
 * accounts are provisioned via the web admin console only (locked decision: MFA
 * mandatory for admin role; mobile app does not expose admin onboarding).
 */
enum class UserRole(val storageKey: String, val displayName: String, val description: String) {
    // storageKey values mirror the server `user_role` enum verbatim.
    // displayName matches the AccountTypeSection title on ProfileScreen
    // ("Hospital admin") — the previous "Hospital buyer" only appeared
    // on the role-editor sheet, leaving the snackbar saying "Role
    // updated to Hospital buyer" while the Profile said "Hospital
    // admin". Indian hospital users identify as admins, not buyers.
    // v1: parts marketplace deferred. Description trimmed so the
    // role-editor + signup tiles don't promise "Buy parts".
    HOSPITAL("hospital_admin", "Hospital admin", "Book engineers, manage repairs"),
    // displayName matches the AccountTypeSection title — Profile said
    // "Biomedical engineer" while the role-editor said "Field engineer".
    // "Biomedical" is the domain (matches the directory headline
    // "Browse verified biomedical engineers near you"), so unify on it.
    ENGINEER("engineer", "Biomedical engineer", "Pick up jobs, bid, complete repairs"),
    SUPPLIER("supplier", "Parts supplier", "List parts and fulfil orders"),
    MANUFACTURER("manufacturer", "Manufacturer", "Receive RFQs and respond to leads"),
    LOGISTICS("logistics", "Logistics partner", "Pick up and deliver shipments");

    companion object {
        fun fromKey(key: String?): UserRole? = entries.firstOrNull { it.storageKey == key }
    }
}
