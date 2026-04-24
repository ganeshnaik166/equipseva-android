package com.equipseva.app.designsystem.components

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke

/**
 * 17 SVG-derived equipment illustrations rendered to a 100x100 viewBox using Compose Canvas.
 * Hue cheatsheet: green=150, amber=40, blue=200, red=0, purple=280, pink=330.
 */
enum class EquipmentArt {
    MedicalServices,
    MonitorHeart,
    Radiology,
    Air,
    Vaccines,
    Masks,
    Build,
    LocalShipping,
    Replay,
    Photo,
    Error,
    Image,
    Category,
    LocalHospital,
    Engineering,
    Inventory,
    PrecisionManufacturing,
}

private data class ArtPalette(
    val bgA: Color,
    val bgB: Color,
    val artA: Color,
    val artB: Color,
    val artBg: Color,
)

private fun palette(hue: Int): ArtPalette {
    val h = hue.toFloat().coerceIn(0f, 360f)
    return ArtPalette(
        bgA = Color.hsl(h, saturation = 0.20f, lightness = 0.94f),
        bgB = Color.hsl(h, saturation = 0.30f, lightness = 0.86f),
        artA = Color.hsl(h, saturation = 0.32f, lightness = 0.86f),
        artB = Color.hsl(h, saturation = 0.40f, lightness = 0.30f),
        artBg = Color.hsl(h, saturation = 0.10f, lightness = 0.97f),
    )
}

@Composable
fun EquipmentIllustration(
    art: EquipmentArt,
    hue: Int = 150,
    modifier: Modifier = Modifier,
) {
    val pal = palette(hue)
    Canvas(modifier = modifier) {
        // Background radial-style gradients + base fill (approximation of design's bg).
        val w = size.width
        val h = size.height
        drawRect(color = pal.bgA, topLeft = Offset(0f, 0f), size = Size(w, h))
        drawRect(
            brush = Brush.radialGradient(
                colors = listOf(pal.bgA, Color.Transparent),
                center = Offset(w * 0.25f, h * 0.20f),
                radius = w * 0.6f,
            ),
            topLeft = Offset(0f, 0f),
            size = Size(w, h),
        )
        drawRect(
            brush = Brush.radialGradient(
                colors = listOf(pal.bgB, Color.Transparent),
                center = Offset(w * 0.85f, h * 0.90f),
                radius = w * 0.55f,
            ),
            topLeft = Offset(0f, 0f),
            size = Size(w, h),
        )
        when (art) {
            EquipmentArt.MedicalServices -> drawMedicalServices(pal)
            EquipmentArt.MonitorHeart -> drawMonitorHeart(pal)
            EquipmentArt.Radiology -> drawRadiology(pal)
            EquipmentArt.Air -> drawAir(pal)
            EquipmentArt.Vaccines -> drawVaccines(pal)
            EquipmentArt.Masks -> drawMasks(pal)
            EquipmentArt.Build -> drawBuild(pal)
            EquipmentArt.LocalShipping -> drawLocalShipping(pal)
            EquipmentArt.Replay -> drawReplay(pal)
            EquipmentArt.Photo -> drawPhoto(pal)
            EquipmentArt.Error -> drawError(pal)
            EquipmentArt.Image -> drawImage(pal)
            EquipmentArt.Category -> drawCategory(pal)
            EquipmentArt.LocalHospital -> drawLocalHospital(pal)
            EquipmentArt.Engineering -> drawEngineering(pal)
            EquipmentArt.Inventory -> drawInventory(pal)
            EquipmentArt.PrecisionManufacturing -> drawPrecisionManufacturing(pal)
        }
    }
}

// ---------- helpers ----------

private val DrawScope.scale: Float get() = size.minDimension / 100f

private fun DrawScope.s(v: Float): Float = v * scale
private fun DrawScope.off(x: Float, y: Float): Offset = Offset(s(x), s(y))
private fun DrawScope.sz(w: Float, h: Float): Size = Size(s(w), s(h))

private fun DrawScope.fillRect(c: Color, x: Float, y: Float, w: Float, h: Float) {
    drawRect(color = c, topLeft = off(x, y), size = sz(w, h))
}

private fun DrawScope.strokeRect(c: Color, x: Float, y: Float, w: Float, h: Float, sw: Float = 1.5f) {
    drawRect(
        color = c,
        topLeft = off(x, y),
        size = sz(w, h),
        style = Stroke(width = s(sw)),
    )
}

private fun DrawScope.fillCircle(c: Color, cx: Float, cy: Float, r: Float) {
    drawCircle(color = c, radius = s(r), center = off(cx, cy))
}

private fun DrawScope.strokeCircle(c: Color, cx: Float, cy: Float, r: Float, sw: Float = 1.5f) {
    drawCircle(
        color = c,
        radius = s(r),
        center = off(cx, cy),
        style = Stroke(width = s(sw)),
    )
}

private fun DrawScope.fillPath(c: Color, build: Path.() -> Unit) {
    val p = Path().apply(build)
    drawPath(p, color = c, style = Fill)
}

private fun DrawScope.strokePath(
    c: Color,
    sw: Float = 1.5f,
    cap: StrokeCap = StrokeCap.Butt,
    join: StrokeJoin = StrokeJoin.Miter,
    pathEffect: PathEffect? = null,
    build: Path.() -> Unit,
) {
    val p = Path().apply(build)
    drawPath(
        p,
        color = c,
        style = Stroke(width = s(sw), cap = cap, join = join, pathEffect = pathEffect),
    )
}

private fun DrawScope.fillAndStrokePath(
    fillColor: Color,
    strokeColor: Color,
    sw: Float = 1.5f,
    join: StrokeJoin = StrokeJoin.Miter,
    cap: StrokeCap = StrokeCap.Butt,
    build: Path.() -> Unit,
) {
    val p = Path().apply(build)
    drawPath(p, color = fillColor, style = Fill)
    drawPath(p, color = strokeColor, style = Stroke(width = s(sw), join = join, cap = cap))
}

// SVG path helpers (in viewBox units; scaling happens at draw-time via Path multiplied).
// We build paths in scaled coordinates directly for simplicity.
private fun Path.M(x: Float, y: Float) = moveTo(x, y)
private fun Path.L(x: Float, y: Float) = lineTo(x, y)
private fun Path.Q(cx: Float, cy: Float, x: Float, y: Float) = quadraticBezierTo(cx, cy, x, y)

// Approximate an SVG arc with a series of small line segments (sufficient for our visuals).
private fun Path.arcApprox(
    cx: Float, cy: Float, r: Float,
    startDeg: Float, endDeg: Float,
    segments: Int = 48,
) {
    val startRad = Math.toRadians(startDeg.toDouble())
    val sx = (cx + r * Math.cos(startRad)).toFloat()
    val sy = (cy + r * Math.sin(startRad)).toFloat()
    M(sx, sy)
    for (i in 1..segments) {
        val t = i.toFloat() / segments
        val ang = startDeg + (endDeg - startDeg) * t
        val rad = Math.toRadians(ang.toDouble())
        val x = (cx + r * Math.cos(rad)).toFloat()
        val y = (cy + r * Math.sin(rad)).toFloat()
        L(x, y)
    }
}

// ---------- illustrations ----------

private fun DrawScope.drawMedicalServices(c: ArtPalette) {
    // <rect x="28" y="18" width="44" height="30" rx="4" fill=a stroke=b sw=1.5/>
    fillRect(c.artA, 28f, 18f, 44f, 30f)
    strokeRect(c.artB, 28f, 18f, 44f, 30f, 1.5f)
    // <circle cx="50" cy="62" r="16" fill=a stroke=b sw=1.5/>
    fillCircle(c.artA, 50f, 62f, 16f)
    strokeCircle(c.artB, 50f, 62f, 16f, 1.5f)
    // plus: M46 62h8 M50 58v8  sw=2 round
    strokePath(c.artB, sw = 2f, cap = StrokeCap.Round) {
        M(s(46f), s(62f)); L(s(54f), s(62f))
        M(s(50f), s(58f)); L(s(50f), s(66f))
    }
    // inner highlight rect
    fillRect(c.artBg.copy(alpha = 0.6f), 34f, 24f, 32f, 18f)
}

private fun DrawScope.drawMonitorHeart(c: ArtPalette) {
    fillRect(c.artA, 18f, 22f, 64f, 42f)
    strokeRect(c.artB, 18f, 22f, 64f, 42f, 1.5f)
    fillRect(c.artBg, 24f, 28f, 52f, 30f)
    // ECG path
    strokePath(c.artB, sw = 1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round) {
        M(s(28f), s(44f))
        L(s(36f), s(44f))
        L(s(40f), s(34f))
        L(s(46f), s(50f))
        L(s(50f), s(44f))
        L(s(56f), s(44f))
        L(s(60f), s(40f))
        L(s(66f), s(48f))
        L(s(70f), s(44f))
        L(s(82f), s(44f))
    }
    // base bar
    fillRect(c.artB, 38f, 68f, 24f, 3f)
}

private fun DrawScope.drawRadiology(c: ArtPalette) {
    fillRect(c.artA, 10f, 20f, 80f, 56f)
    strokeRect(c.artB, 10f, 20f, 80f, 56f, 1.5f)
    fillCircle(c.artBg, 50f, 48f, 22f)
    strokeCircle(c.artB, 50f, 48f, 22f, 1.5f)
    fillCircle(c.artA, 50f, 48f, 12f)
    fillCircle(c.artB, 50f, 48f, 4f)
    val faded = c.artB.copy(alpha = 0.4f)
    fillRect(faded, 24f, 28f, 6f, 4f)
    fillRect(faded, 70f, 28f, 6f, 4f)
}

private fun DrawScope.drawAir(c: ArtPalette) {
    fillRect(c.artA, 22f, 14f, 56f, 68f)
    strokeRect(c.artB, 22f, 14f, 56f, 68f, 1.5f)
    fillRect(c.artBg, 28f, 20f, 44f, 22f)
    fillCircle(c.artBg, 50f, 58f, 10f)
    strokeCircle(c.artB, 50f, 58f, 10f, 1.2f)
    fillCircle(c.artB, 50f, 58f, 4f)
    fillRect(c.artB.copy(alpha = 0.5f), 32f, 72f, 36f, 3f)
    strokePath(c.artB.copy(alpha = 0.5f), sw = 1f) {
        M(s(34f), s(26f)); L(s(64f), s(36f))
        M(s(34f), s(30f)); L(s(58f), s(34f))
    }
}

private fun DrawScope.drawVaccines(c: ArtPalette) {
    fillRect(c.artA, 24f, 30f, 52f, 40f)
    strokeRect(c.artB, 24f, 30f, 52f, 40f, 1.5f)
    strokePath(c.artB, sw = 1f) { M(s(24f), s(42f)); L(s(76f), s(42f)) }
    fillRect(c.artB.copy(alpha = 0.4f), 30f, 36f, 10f, 3f)
    // diamond syringe shape: M46 50 l16 -16 l6 6 l-16 16z
    fillAndStrokePath(c.artBg, c.artB, sw = 1.2f) {
        M(s(46f), s(50f))
        L(s(46f + 16f), s(50f - 16f))
        L(s(62f + 6f), s(34f + 6f))
        L(s(68f - 16f), s(40f + 16f))
        close()
    }
}

private fun DrawScope.drawMasks(c: ArtPalette) {
    // M20 34 Q50 24 80 34 L76 60 Q50 70 24 60 Z
    fillAndStrokePath(c.artA, c.artB, sw = 1.5f) {
        M(s(20f), s(34f))
        Q(s(50f), s(24f), s(80f), s(34f))
        L(s(76f), s(60f))
        Q(s(50f), s(70f), s(24f), s(60f))
        close()
    }
    // ear loops
    strokePath(c.artB, sw = 1.2f, cap = StrokeCap.Round) {
        M(s(20f), s(40f)); L(s(10f), s(42f))
        M(s(80f), s(40f)); L(s(90f), s(42f))
    }
    // pleats
    strokePath(c.artB.copy(alpha = 0.5f), sw = 0.8f) {
        M(s(32f), s(42f)); L(s(68f), s(42f))
        M(s(32f), s(50f)); L(s(68f), s(50f))
    }
}

private fun DrawScope.drawBuild(c: ArtPalette) {
    // Wrench-like shape
    fillAndStrokePath(c.artA, c.artB, sw = 1.5f, join = StrokeJoin.Round) {
        // M30 20 l12 12 l-6 6 l22 22 l6 -6 l12 12 l-8 8 l-12 -12 l-6 6 l-22 -22 l6 -6 l-12 -12z
        var x = 30f; var y = 20f
        M(s(x), s(y))
        x += 12f; y += 12f; L(s(x), s(y))
        x -= 6f; y += 6f; L(s(x), s(y))
        x += 22f; y += 22f; L(s(x), s(y))
        x += 6f; y -= 6f; L(s(x), s(y))
        x += 12f; y += 12f; L(s(x), s(y))
        x -= 8f; y += 8f; L(s(x), s(y))
        x -= 12f; y -= 12f; L(s(x), s(y))
        x -= 6f; y += 6f; L(s(x), s(y))
        x -= 22f; y -= 22f; L(s(x), s(y))
        x += 6f; y -= 6f; L(s(x), s(y))
        x -= 12f; y -= 12f; L(s(x), s(y))
        close()
    }
}

private fun DrawScope.drawLocalShipping(c: ArtPalette) {
    fillRect(c.artA, 10f, 38f, 50f, 26f)
    strokeRect(c.artB, 10f, 38f, 50f, 26f, 1.5f)
    // cab: M60 44 l18 0 l8 10 l0 10 l-26 0z
    fillAndStrokePath(c.artA, c.artB, sw = 1.5f, join = StrokeJoin.Round) {
        M(s(60f), s(44f))
        L(s(78f), s(44f))
        L(s(86f), s(54f))
        L(s(86f), s(64f))
        L(s(60f), s(64f))
        close()
    }
    // wheels
    fillCircle(c.artB, 28f, 66f, 6f)
    fillCircle(c.artB, 72f, 66f, 6f)
    fillCircle(c.artBg, 28f, 66f, 2.5f)
    fillCircle(c.artBg, 72f, 66f, 2.5f)
}

private fun DrawScope.drawReplay(c: ArtPalette) {
    // M30 30 A 22 22 0 1 1 22 56 — large arc, sweep=1 (clockwise)
    // From (30,30) on a circle of radius ~22, going clockwise, large arc to (22,56).
    // Approximate: center of circle that passes both (30,30) and (22,56) with r=22.
    // Simpler: draw a 270deg arc around center (50,50) r=22 that visually matches.
    strokePath(c.artB, sw = 3f, cap = StrokeCap.Round) {
        // Arc from -135deg to ~150deg around center (50,50) r=22
        val cx = s(50f); val cy = s(50f); val r = s(22f)
        val startDeg = -135f
        val endDeg = 135f
        val segs = 48
        val sRad = Math.toRadians(startDeg.toDouble())
        M((cx + r * Math.cos(sRad)).toFloat(), (cy + r * Math.sin(sRad)).toFloat())
        for (i in 1..segs) {
            val t = i.toFloat() / segs
            val ang = startDeg + (endDeg - startDeg) * t
            val rad = Math.toRadians(ang.toDouble())
            L((cx + r * Math.cos(rad)).toFloat(), (cy + r * Math.sin(rad)).toFloat())
        }
    }
    // Arrow head: M22 22 L32 30 L22 38 Z
    fillPath(c.artB) {
        M(s(22f), s(22f))
        L(s(32f), s(30f))
        L(s(22f), s(38f))
        close()
    }
}

private fun DrawScope.drawPhoto(c: ArtPalette) {
    fillRect(c.artA, 16f, 22f, 68f, 56f)
    strokeRect(c.artB, 16f, 22f, 68f, 56f, 1.5f)
    fillCircle(c.artB.copy(alpha = 0.6f), 36f, 42f, 6f)
    // mountain path: M16 64 l20 -18 l14 12 l10 -8 l24 22
    fillAndStrokePath(c.artBg, c.artB, sw = 1.2f) {
        M(s(16f), s(64f))
        L(s(36f), s(46f))
        L(s(50f), s(58f))
        L(s(60f), s(50f))
        L(s(84f), s(72f))
        // close along bottom for fill
        L(s(84f), s(78f))
        L(s(16f), s(78f))
        close()
    }
}

private fun DrawScope.drawError(c: ArtPalette) {
    fillCircle(c.artA, 50f, 50f, 28f)
    strokeCircle(c.artB, 50f, 50f, 28f, 1.5f)
    strokePath(c.artB, sw = 4f, cap = StrokeCap.Round) {
        M(s(50f), s(38f)); L(s(50f), s(54f))
        M(s(50f), s(60f)); L(s(50f), s(62f))
    }
}

private fun DrawScope.drawImage(c: ArtPalette) {
    fillRect(c.artA, 14f, 20f, 72f, 60f)
    strokeRect(c.artB, 14f, 20f, 72f, 60f, 1.5f)
    fillCircle(c.artB.copy(alpha = 0.5f), 32f, 38f, 5f)
    fillAndStrokePath(c.artBg, c.artB, sw = 1.2f) {
        M(s(14f), s(62f))
        L(s(36f), s(42f))
        L(s(50f), s(54f))
        L(s(62f), s(44f))
        L(s(86f), s(66f))
        L(s(86f), s(80f))
        L(s(14f), s(80f))
        close()
    }
}

private fun DrawScope.drawCategory(c: ArtPalette) {
    fillRect(c.artA, 18f, 18f, 28f, 28f); strokeRect(c.artB, 18f, 18f, 28f, 28f, 1.5f)
    fillRect(c.artBg, 54f, 18f, 28f, 28f); strokeRect(c.artB, 54f, 18f, 28f, 28f, 1.5f)
    fillRect(c.artBg, 18f, 54f, 28f, 28f); strokeRect(c.artB, 18f, 54f, 28f, 28f, 1.5f)
    fillRect(c.artA, 54f, 54f, 28f, 28f); strokeRect(c.artB, 54f, 54f, 28f, 28f, 1.5f)
}

private fun DrawScope.drawLocalHospital(c: ArtPalette) {
    // House outline: M18 44 L50 18 L82 44 L82 82 L18 82 Z
    fillAndStrokePath(c.artA, c.artB, sw = 1.8f, join = StrokeJoin.Round) {
        M(s(18f), s(44f))
        L(s(50f), s(18f))
        L(s(82f), s(44f))
        L(s(82f), s(82f))
        L(s(18f), s(82f))
        close()
    }
    fillRect(c.artBg, 30f, 52f, 40f, 30f)
    // plus: M44 58 h12 v8 h8 v8 h-12 v-8 h-8 z (cross)
    fillPath(c.artB) {
        var x = 44f; var y = 58f
        M(s(x), s(y))
        x += 12f; L(s(x), s(y))
        y += 8f; L(s(x), s(y))
        x += 8f; L(s(x), s(y))
        y += 8f; L(s(x), s(y))
        x -= 12f; L(s(x), s(y))
        y += 8f; L(s(x), s(y))
        x -= 8f; L(s(x), s(y))
        y -= 8f; L(s(x), s(y))
        x -= 8f; L(s(x), s(y))
        close()
    }
}

private fun DrawScope.drawEngineering(c: ArtPalette) {
    // Sun-gear circle
    fillCircle(c.artA, 36f, 36f, 14f)
    strokeCircle(c.artB, 36f, 36f, 14f, 1.8f)
    fillCircle(c.artBg, 36f, 36f, 5f)
    strokeCircle(c.artB, 36f, 36f, 5f, 1.2f)
    // rays
    strokePath(c.artB, sw = 1.8f, cap = StrokeCap.Round) {
        M(s(36f), s(16f)); L(s(36f), s(22f))
        M(s(36f), s(50f)); L(s(36f), s(56f))
        M(s(16f), s(36f)); L(s(22f), s(36f))
        M(s(50f), s(36f)); L(s(56f), s(36f))
        M(s(22f), s(22f)); L(s(26f), s(26f))
        M(s(46f), s(46f)); L(s(50f), s(50f))
        M(s(22f), s(50f)); L(s(26f), s(46f))
        M(s(46f), s(26f)); L(s(50f), s(22f))
    }
    // wrench head: M56 58 l20 20 l-6 6 l-20 -20 z
    fillAndStrokePath(c.artA, c.artB, sw = 1.5f, join = StrokeJoin.Round) {
        M(s(56f), s(58f))
        L(s(76f), s(78f))
        L(s(70f), s(84f))
        L(s(50f), s(64f))
        close()
    }
    fillCircle(c.artB, 58f, 60f, 3f)
}

private fun DrawScope.drawInventory(c: ArtPalette) {
    fillRect(c.artA, 18f, 28f, 64f, 48f)
    strokeRect(c.artB, 18f, 28f, 64f, 48f, 1.8f)
    strokePath(c.artB, sw = 1.5f) { M(s(18f), s(42f)); L(s(82f), s(42f)) }
    fillRect(c.artBg, 40f, 28f, 20f, 14f); strokeRect(c.artB, 40f, 28f, 20f, 14f, 1.2f)
    strokePath(c.artB, sw = 1.2f, cap = StrokeCap.Round) {
        M(s(44f), s(32f)); L(s(56f), s(32f))
        M(s(44f), s(36f)); L(s(56f), s(36f))
    }
    fillRect(c.artBg, 26f, 50f, 18f, 20f); strokeRect(c.artB, 26f, 50f, 18f, 20f, 1f)
    fillRect(c.artBg, 56f, 50f, 18f, 20f); strokeRect(c.artB, 56f, 50f, 18f, 20f, 1f)
}

private fun DrawScope.drawPrecisionManufacturing(c: ArtPalette) {
    // base
    fillRect(c.artA, 14f, 60f, 72f, 20f)
    strokeRect(c.artB, 14f, 60f, 72f, 20f, 1.5f)
    // arm path: M26 60 L26 40 L52 40 L52 30 L74 30 L74 60
    fillAndStrokePath(c.artA, c.artB, sw = 1.8f, join = StrokeJoin.Round) {
        M(s(26f), s(60f))
        L(s(26f), s(40f))
        L(s(52f), s(40f))
        L(s(52f), s(30f))
        L(s(74f), s(30f))
        L(s(74f), s(60f))
        // close along bottom for fill
        close()
    }
    fillCircle(c.artBg, 36f, 52f, 5f); strokeCircle(c.artB, 36f, 52f, 5f, 1.2f)
    fillCircle(c.artBg, 64f, 46f, 5f); strokeCircle(c.artB, 64f, 46f, 5f, 1.2f)
    fillRect(c.artB, 44f, 68f, 4f, 6f)
    fillRect(c.artB, 54f, 68f, 4f, 6f)
}
