package com.equipseva.app.designsystem.theme

import android.app.Application
import android.graphics.Typeface
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalFontFamilyResolver
import androidx.compose.ui.text.font.FontSynthesis
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import androidx.core.graphics.ColorUtils
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Runs against the public production theme; expected values come from the approved UI plan. */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LimeThemeFoundationTest {
    private lateinit var host: ActivityController<ComponentActivity>

    @Before fun open() {
        IsolatedUiPackageParser.assertIsolated(ApplicationProvider.getApplicationContext())
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }
    @After fun close() { host.pause().stop().destroy() }

    private fun theme(dark: Boolean = false, assertions: @Composable () -> Unit) {
        var ran = false
        host.get().setContent { EquipSevaTheme(darkTheme = dark) { assertions(); ran = true } }
        org.robolectric.Shadows.shadowOf(android.os.Looper.getMainLooper()).idle()
        assertTrue("Production theme assertions must execute", ran)
    }

    @Test fun `light theme has soft canvas and lime action container with safe foreground primary`() = theme {
        val c = MaterialTheme.colorScheme
        assertEquals(Color(0xFFF4F5F2), c.background)
        assertEquals(Color.White, c.surface)
        assertEquals(Color(0xFFC6FF00), c.primaryContainer)
        contrast(c.onPrimaryContainer, c.primaryContainer, 4.5)
        contrast(c.primary, c.surface, 4.5)
        contrast(c.onPrimary, c.primary, 4.5)
        contrast(c.outline, c.background, 3.0)
    }

    @Test fun `dark theme has ink canvas and readable surface and error roles`() = theme(true) {
        val c = MaterialTheme.colorScheme
        assertEquals(Color(0xFF0C0F0B), c.background)
        assertEquals(Color(0xFF1B2018), c.surface)
        assertEquals(Color(0xFFC6FF00), c.primaryContainer)
        contrast(c.onSurface, c.surface, 4.5)
        contrast(c.onSurfaceVariant, c.surfaceVariant, 4.5)
        contrast(c.onErrorContainer, c.errorContainer, 4.5)
        contrast(c.error, c.surface, 4.5)
    }

    @Test fun `legacy and Material text use the same readable page and body styles`() = theme {
        val t = MaterialTheme.typography
        assertEquals(28.sp, t.headlineLarge.fontSize)
        assertEquals(34.sp, t.headlineLarge.lineHeight)
        assertEquals(FontWeight.SemiBold, t.headlineLarge.fontWeight)
        assertEquals(t.headlineLarge, EsType.H2)
        assertEquals(t.bodyLarge, EsType.Body)
        assertEquals(16.sp, t.bodyLarge.fontSize)
        assertEquals(24.sp, t.bodyLarge.lineHeight)
        assertEquals(16.sp, t.labelLarge.fontSize)
        assertEquals(FontWeight.SemiBold, t.labelLarge.fontWeight)
        assertEquals(0.sp, t.bodyLarge.letterSpacing)
        assertNotEquals(t.bodyLarge.fontFamily, t.headlineLarge.fontFamily)
    }

    @Test fun `shape roles separate inputs cards and sheets`() = theme {
        val s = MaterialTheme.shapes
        assertEquals(16f, s.medium.topStart.toPx(Size(100f, 100f), Density(1f)))
        assertEquals(24f, s.large.topStart.toPx(Size(100f, 100f), Density(1f)))
        assertEquals(28f, s.extraLarge.topStart.toPx(Size(100f, 100f), Density(1f)))
    }

    @Test fun `production typography resolves actual bundled weights`() = theme {
        val resolver = LocalFontFamilyResolver.current
        val t = MaterialTheme.typography
        val title = resolver.resolve(t.headlineLarge.fontFamily, FontWeight.SemiBold,
            fontSynthesis = FontSynthesis.None).value as Typeface
        assertEquals(600, title.weight)
        listOf(FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold).forEach { weight ->
            val body = resolver.resolve(t.bodyLarge.fontFamily, weight,
                fontSynthesis = FontSynthesis.None).value as Typeface
            assertEquals(weight.weight, body.weight)
        }
        assertNotEquals("Headings must load Space Grotesk, not the Inter body", title,
            resolver.resolve(t.bodyLarge.fontFamily, FontWeight.SemiBold,
                fontSynthesis = FontSynthesis.None).value)
    }

    @Test fun `all font weights and licenses are packaged offline`() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        listOf("space_grotesk_semibold", "inter_regular", "inter_medium", "inter_semibold",
            "noto_sans_devanagari_regular", "noto_sans_devanagari_medium", "noto_sans_devanagari_semibold",
            "noto_sans_telugu_regular", "noto_sans_telugu_medium", "noto_sans_telugu_semibold").forEach { name ->
            val id = app.resources.getIdentifier(name, "font", app.packageName)
            assertNotEquals("Missing offline font: $name", 0, id)
            assertNotNull(app.resources.getFont(id))
        }
        assertTrue("Bundled font licence notices", app.assets.list("font_licenses")!!.size >= 4)
    }

    @Test fun `explicit wallpaper opt in affects Material while brand pairs remain fixed`() = theme {
        val app = ApplicationProvider.getApplicationContext<Application>()
        EquipSevaTheme(darkTheme = false, dynamicColor = true) {
            val expected = androidx.compose.material3.dynamicLightColorScheme(app)
            assertEquals(expected.primary, MaterialTheme.colorScheme.primary)
            assertEquals(expected.surface, MaterialTheme.colorScheme.surface)
            assertEquals(expected.background, MaterialTheme.colorScheme.background)
            assertEquals(Color(0xFFC6FF00), EsTheme.colors.action.container)
            contrast(EsTheme.colors.action.content, EsTheme.colors.action.container, 4.5)
        }
    }

    @Test fun `legacy font getter safely supports an outer Material style with no explicit family`() = theme {
        MaterialTheme(typography = MaterialTheme.typography.copy(
            bodyLarge = MaterialTheme.typography.bodyLarge.copy(fontFamily = null),
        )) {
            assertEquals(androidx.compose.ui.text.font.FontFamily.Default, EsFontFamily)
        }
    }

    private fun contrast(fg: Color, bg: Color, min: Double) {
        val ratio = ColorUtils.calculateContrast(fg.toArgb(), bg.toArgb())
        assertTrue("$fg on $bg: $ratio < $min", ratio >= min)
    }
}
