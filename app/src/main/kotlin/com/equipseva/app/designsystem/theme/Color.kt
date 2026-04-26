package com.equipseva.app.designsystem.theme

import androidx.compose.ui.graphics.Color

// Brand — matches tokens.css --brand-*
val BrandGreen = Color(0xFF0B6E4F)        // --brand-600
val BrandGreenDark = Color(0xFF075A40)    // --brand-700
val BrandGreenLight = Color(0xFF2E8B6E)
val BrandGreen50 = Color(0xFFE6F2ED)      // --brand-50
val BrandGreen100 = Color(0xFFCFE4DB)     // --brand-100
val BrandGreenDeep = Color(0xFF032F03)    // S5 vibrant logo deep accent

// S5 vibrant electric-lime accent (signature pop from new logo)
val AccentLime = Color(0xFF0FFF13)        // --accent-lime
val AccentLimeBright = Color(0xFF6BFF6E)  // saturated highlight tint
val AccentLimeSoft = Color(0x290FFF13)    // 16% alpha — chip backgrounds, glows

// Back-compat alias
val Color98Green = BrandGreen50

// Neutrals — matches tokens.css --n-*
val Ink900 = Color(0xFF111418)            // --n-900
val Ink800 = Color(0xFF1B1F26)            // --n-800
val Ink700 = Color(0xFF3F4650)            // --n-700
val Ink500 = Color(0xFF6B7280)            // --n-500
val Ink400 = Color(0xFF9AA1AC)            // --n-400
val Ink300 = Color(0xFFC7CCD3)            // --n-300
val Surface0 = Color(0xFFFFFFFF)          // --surface
val Surface50 = Color(0xFFF7F8FA)         // --n-50
val Surface100 = Color(0xFFEFF1F4)        // --n-100
val Surface200 = Color(0xFFE6E8EC)        // --n-200
val Outline = Color(0xFFE6E8EC)

// Dark surface elevation
val InkSurface = Color(0xFF1B1F26)

// Status — matches tokens.css --s-*
val Success = Color(0xFF1E8A5F)           // --s-success
val SuccessBg = Color(0xFFE3F4EB)         // --s-success-bg
val Warning = Color(0xFFD98B18)           // --s-warning
val WarningBg = Color(0xFFFBEFDA)         // --s-warning-bg
val Info = Color(0xFF1F6FEB)              // --s-info
val InfoBg = Color(0xFFDCE8FB)            // --s-info-bg
val ErrorRed = Color(0xFFC8372D)          // --s-danger
val ErrorBg = Color(0xFFFADBD8)           // --s-danger-bg
