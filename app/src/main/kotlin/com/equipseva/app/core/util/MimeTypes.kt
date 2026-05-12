package com.equipseva.app.core.util

/** Common MIME types used across upload, picker, and validator paths. */
const val MIME_JPEG = "image/jpeg"
const val MIME_PNG = "image/png"
const val MIME_WEBP = "image/webp"
const val MIME_PDF = "application/pdf"

/** Accepted image MIME types for avatar / photo / before/after uploads. */
val IMAGE_MIME_TYPES = setOf(MIME_JPEG, MIME_PNG, MIME_WEBP)
