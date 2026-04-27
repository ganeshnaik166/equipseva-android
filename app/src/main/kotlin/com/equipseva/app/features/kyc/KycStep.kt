package com.equipseva.app.features.kyc

/**
 * Two-step engineer onboarding wizard. Step 1 captures personal contact
 * info (name, email + verify, phone + verify, city, state); Step 2 stacks
 * all four document uploads (Aadhaar, PAN, selfie, trade certificate) plus
 * the attestation checkbox in a single scrollable page.
 *
 * Skills / service radius / hourly rate / specializations live on the
 * separate engineer-profile editor (Routes.ENGINEER_PROFILE) — engineers
 * fill those in after admin approves their KYC.
 */
enum class KycStep(
    val number: Int,
    val title: String,
    val subtitle: String,
) {
    Personal(
        number = 1,
        title = "Personal",
        subtitle = "Name, email, phone",
    ),
    Documents(
        number = 2,
        title = "Documents",
        subtitle = "Upload your IDs + selfie + certificate",
    );

    fun next(): KycStep? = entries.getOrNull(ordinal + 1)
    fun previous(): KycStep? = entries.getOrNull(ordinal - 1)

    val isFirst: Boolean get() = ordinal == 0
    val isLast: Boolean get() = ordinal == entries.lastIndex

    companion object {
        val total: Int get() = entries.size
    }
}
