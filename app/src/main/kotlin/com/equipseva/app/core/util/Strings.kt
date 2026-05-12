package com.equipseva.app.core.util

/**
 * Title-case a snake_case or kebab-case key for display.
 * "image_processor" -> "Image Processor", "ct-scanner" -> "Ct Scanner".
 */
fun prettyKey(key: String): String =
    key.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }
