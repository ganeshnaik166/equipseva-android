package com.equipseva.app.core.util

import java.util.Locale

/**
 * Title-case a snake_case or kebab-case key for display.
 * "image_processor" -> "Image Processor", "ct-scanner" -> "Ct Scanner".
 *
 * Pinned to Locale.ROOT so a Turkish system locale doesn't turn lowercase
 * "i" into capital "İ" (dotted) when titling equipment category labels.
 */
fun prettyKey(key: String): String =
    key.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase(Locale.ROOT) } }
