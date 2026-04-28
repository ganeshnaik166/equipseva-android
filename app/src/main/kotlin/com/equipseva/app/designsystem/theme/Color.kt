package com.equipseva.app.designsystem.theme

import androidx.compose.ui.graphics.Color

// ============================================================
// EquipSeva v1 design system tokens — from `newdesign.zip:tokens.css`.
// Coexists with the legacy `BrandGreen` / `Ink900` / `Surface0` set
// below so old screens keep compiling while new screens migrate to
// the Seva palette one round at a time.
//
// When a Seva token + a legacy token resolve to byte-identical hex,
// the legacy one is aliased to the Seva one (e.g. `BrandGreen ==
// SevaGreen700`). Where they differ, both coexist intentionally —
// the legacy palette stays intact for in-flight screens.
// ============================================================

// --- Seva green (primary brand scale, 11 stops) -----------------
val SevaGreen50  = Color(0xFFE8F5EF)
val SevaGreen100 = Color(0xFFC7E7D6)
val SevaGreen200 = Color(0xFF95D2B2)
val SevaGreen300 = Color(0xFF5FB78B)
val SevaGreen400 = Color(0xFF2C9968)
val SevaGreen500 = Color(0xFF168558)  // hover / active for primary
val SevaGreen600 = Color(0xFF0E7651)  // primary button hover
val SevaGreen700 = Color(0xFF0B6E4F)  // PRIMARY — logo background
val SevaGreen800 = Color(0xFF074B36)  // dense surfaces
val SevaGreen900 = Color(0xFF052F22)  // footer / forest shadow
val SevaGreen950 = Color(0xFF021A12)

// --- Seva glow (decorative halo, sampled from logo neon) --------
val SevaGlow     = Color(0xFF22E06A)  // calmed, usable accent
val SevaGlowRaw  = Color(0xFF0FFF13)  // raw logo halo — backgrounds + hero only
val SevaGlowSoft = Color(0xFFC7F8D4)

// --- Paper (warm-cool surfaces) ---------------------------------
val PaperDefault = Color(0xFFF6F8F5)  // app bg, off-white green wash
val Paper2       = Color(0xFFEEF1ED)  // secondary surface
val Paper3       = Color(0xFFE2E7E2)  // hovered surface / divider

// --- Seva ink (10-stop neutral, distinct from legacy Ink*) ------
val SevaInk50  = Color(0xFFF6F8F5)
val SevaInk100 = Color(0xFFE2E7E2)
val SevaInk200 = Color(0xFFC8D0C9)
val SevaInk300 = Color(0xFFA4AFA8)
val SevaInk400 = Color(0xFF788379)
val SevaInk500 = Color(0xFF525C53)
val SevaInk600 = Color(0xFF3A4239)
val SevaInk700 = Color(0xFF242B25)
val SevaInk800 = Color(0xFF161E18)
val SevaInk900 = Color(0xFF0E1714)  // primary text — near-black with green tint

// --- Seva semantic colors (slightly different hues from legacy) -
val SevaDanger50  = Color(0xFFFCEBEA)
val SevaDanger500 = Color(0xFFC8302C)
val SevaDanger700 = Color(0xFF931E1B)
val SevaWarning50  = Color(0xFFFBF1E0)
val SevaWarning500 = Color(0xFFD9881F)
val SevaWarning700 = Color(0xFF9B5E0F)
val SevaInfo50  = Color(0xFFE5F0F8)
val SevaInfo500 = Color(0xFF1E6AA8)
val SevaInfo700 = Color(0xFF134A77)
val SevaSuccess50  = Color(0xFFE1F4EA)
val SevaSuccess500 = Color(0xFF168558)  // == SevaGreen500 by design
val SevaSuccess700 = Color(0xFF0B6E4F)  // == SevaGreen700

// --- Seva borders -----------------------------------------------
val BorderDefault = Color(0xFFE2E7E2)  // == Paper3
val BorderStrong  = Color(0xFFC8D0C9)  // == SevaInk200
val BorderFocus   = SevaGlow

// ============================================================
// Legacy palette (pre-design-replication) — kept for existing
// screens. New screens should NOT use these names.
// ============================================================

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
