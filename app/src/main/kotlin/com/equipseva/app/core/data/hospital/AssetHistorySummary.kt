package com.equipseva.app.core.data.hospital

/**
 * Human label for an asset-timeline event kind (round 508 unions three
 * sources). Unknown kinds degrade to a de-snaked Title-case fallback so a
 * new server event kind never renders a raw token.
 */
internal fun assetEventLabel(eventKind: String): String = when (eventKind) {
    "repair_job" -> "Repair job"
    "dsr_report" -> "Service report"
    "pm_scheduled" -> "Preventive maintenance"
    else -> eventKind.replace('_', ' ').replaceFirstChar { it.uppercase() }
}
