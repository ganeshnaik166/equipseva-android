package com.equipseva.app.designsystem.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

// EquipSeva v1 typography scale, ported from `newdesign.zip:tokens.css`.
//
// The design's HTML overrides every text element to "Helvetica Neue,
// Helvetica, Arial, sans-serif". Helvetica Neue is proprietary (Linotype)
// and can't be redistributed without a license, so we default to
// FontFamily.SansSerif (Android maps to Roboto, the closest free
// Helvetica-substitute on the platform).
//
// To swap in real Helvetica Neue: drop the .ttf files into
// app/src/main/res/font/ as `helvetica_neue_regular.ttf` /
// `_medium` / `_semibold` / `_bold` / `_bold_italic`, then change
// `EsFontFamily` below to `FontFamily(Font(R.font.helvetica_neue_regular), ...)`.
val EsFontFamily: FontFamily = FontFamily.SansSerif

// --- Size scale (px in design → sp in Compose, 1:1) ---
val EsTextXs   = 12.sp
val EsTextSm   = 14.sp
val EsTextMd   = 16.sp   // base body
val EsTextLg   = 18.sp
val EsTextXl   = 20.sp
val EsText2xl  = 24.sp
val EsText3xl  = 32.sp
val EsText4xl  = 44.sp
val EsText5xl  = 60.sp
val EsText6xl  = 80.sp

// --- Type-style data class (one TextStyle per role) ---
// Ported from the .t-* utility classes in tokens.css. Every string in
// the new design maps to exactly one of these; passing TextStyle around
// is the same dead-simple pattern Material3 Typography uses.

object EsType {
    val Display1: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsText6xl,
        fontWeight = FontWeight.Bold,
        lineHeight = (EsText6xl.value * 1.15f).sp,
        letterSpacing = (-0.02).em,
    )
    val Display2: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsText5xl,
        fontWeight = FontWeight.Bold,
        lineHeight = (EsText5xl.value * 1.15f).sp,
        letterSpacing = (-0.02).em,
    )
    val H1: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsText4xl,
        fontWeight = FontWeight.Bold,
        lineHeight = (EsText4xl.value * 1.15f).sp,
        letterSpacing = (-0.02).em,
    )
    val H2: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsText3xl,
        fontWeight = FontWeight.SemiBold,
        lineHeight = (EsText3xl.value * 1.3f).sp,
        letterSpacing = (-0.01).em,
    )
    val H3: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsText2xl,
        fontWeight = FontWeight.SemiBold,
        lineHeight = (EsText2xl.value * 1.3f).sp,
        letterSpacing = (-0.005).em,
    )
    val H4: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextXl,
        fontWeight = FontWeight.SemiBold,
        lineHeight = (EsTextXl.value * 1.3f).sp,
    )
    val H5: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextLg,
        fontWeight = FontWeight.SemiBold,
        lineHeight = (EsTextLg.value * 1.3f).sp,
    )

    val BodyLg: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextLg,
        fontWeight = FontWeight.Normal,
        lineHeight = (EsTextLg.value * 1.55f).sp,
    )
    val Body: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextMd,
        fontWeight = FontWeight.Normal,
        lineHeight = (EsTextMd.value * 1.55f).sp,
    )
    val BodySm: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextSm,
        fontWeight = FontWeight.Normal,
        lineHeight = (EsTextSm.value * 1.55f).sp,
    )

    val Label: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextSm,
        fontWeight = FontWeight.Medium,
        lineHeight = (EsTextSm.value * 1.3f).sp,
    )
    val Caption: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextXs,
        fontWeight = FontWeight.Normal,
        lineHeight = (EsTextXs.value * 1.3f).sp,
    )
    val Overline: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextXs,
        fontWeight = FontWeight.SemiBold,
        lineHeight = EsTextXs,
        letterSpacing = 0.08.em,
    )

    // Mono is mapped to the same family as everything else per the
    // design's HTML override. tabular-nums lands via `feature` flags
    // we pin at usage sites; here we only set the size + weight.
    val Mono: TextStyle = TextStyle(
        fontFamily = EsFontFamily,
        fontSize = EsTextSm,
        fontWeight = FontWeight.Normal,
        lineHeight = (EsTextSm.value * 1.3f).sp,
    )
}
