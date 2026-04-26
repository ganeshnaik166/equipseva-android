package com.equipseva.app.features.kyc

/**
 * The four-step engineer onboarding wizard. Order matters — `next` / `previous`
 * walk the entries list in declaration order. Each step exposes a short title
 * for the header pill and a one-line subtitle for the step body.
 */
enum class KycStep(
    val number: Int,
    val title: String,
    val subtitle: String,
) {
    Identity(
        number = 1,
        title = "Contact",
        subtitle = "How hospitals reach you",
    ),
    Aadhaar(
        number = 2,
        title = "ID",
        subtitle = "Aadhaar verification",
    ),
    Skills(
        number = 3,
        title = "Skills",
        subtitle = "What you fix and where",
    ),
    Credentials(
        number = 4,
        title = "Proof",
        subtitle = "Upload trade certificate",
    );

    fun next(): KycStep? = entries.getOrNull(ordinal + 1)
    fun previous(): KycStep? = entries.getOrNull(ordinal - 1)

    val isFirst: Boolean get() = ordinal == 0
    val isLast: Boolean get() = ordinal == entries.lastIndex

    companion object {
        val total: Int get() = entries.size
    }
}
