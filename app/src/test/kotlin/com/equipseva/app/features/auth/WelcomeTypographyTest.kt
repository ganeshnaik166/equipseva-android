package com.equipseva.app.features.auth

import android.content.Context
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.sp
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.WelcomeBodyFontFamily
import com.equipseva.app.designsystem.theme.WelcomeHeadingFontFamily
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Welcome-only typography contract; the shared app typefaces stay unchanged. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35])
class WelcomeTypographyTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun heading_uses_bundled_space_grotesk_at_semibold_weight() {
        assertNotEquals(FontFamily.SansSerif, EsType.WelcomeBrand.fontFamily)
        assertEquals(WelcomeHeadingFontFamily, EsType.WelcomeBrand.fontFamily)
        assertEquals(FontWeight.SemiBold, EsType.WelcomeBrand.fontWeight)
        assertEquals(28.sp, EsType.WelcomeBrand.fontSize)
        assertEquals(34.sp, EsType.WelcomeBrand.lineHeight)
        assertEquals(EsType.WelcomeBrand.fontFamily, EsType.WelcomeBrandCompact.fontFamily)
        composeRule.setContent {
            EquipSevaTheme { WelcomeScreen(onSignIn = {}, onSignUp = {}) }
        }
        assertEquals(EsType.WelcomeBrand.fontFamily, renderedStyle("EquipSeva").fontFamily)
    }

    @Test
    fun body_and_supporting_copy_use_bundled_inter() {
        assertNotEquals(FontFamily.SansSerif, EsType.WelcomeTagline.fontFamily)
        assertEquals(WelcomeBodyFontFamily, EsType.WelcomeTagline.fontFamily)
        assertEquals(EsType.WelcomeTagline.fontFamily, EsType.WelcomeLegal.fontFamily)
        assertEquals(FontWeight.Normal, EsType.WelcomeTagline.fontWeight ?: FontWeight.Normal)
    }

    @Test
    fun both_welcome_actions_render_in_inter_at_semibold_weight() {
        composeRule.setContent {
            EquipSevaTheme { WelcomeScreen(onSignIn = {}, onSignUp = {}) }
        }

        val signIn = renderedStyle("Sign in")
        val createAccount = renderedStyle("Create account")
        assertNotEquals(FontFamily.SansSerif, signIn.fontFamily)
        assertEquals(WelcomeBodyFontFamily, signIn.fontFamily)
        assertEquals(signIn.fontFamily, createAccount.fontFamily)
        assertEquals(FontWeight.SemiBold, signIn.fontWeight)
        assertEquals(FontWeight.SemiBold, createAccount.fontWeight)
    }

    @Test
    fun shared_button_default_typeface_is_unchanged() {
        composeRule.setContent {
            EquipSevaTheme { EsBtn(text = "Default button", onClick = {}) }
        }
        assertEquals(EsType.Label.fontFamily, renderedStyle("Default button").fontFamily)
        assertEquals(EsType.Label.fontWeight, renderedStyle("Default button").fontWeight)
    }

    @Test
    fun official_font_files_are_packaged_as_local_resources() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        listOf("space_grotesk_variable", "inter_variable").forEach { name ->
            assertNotEquals("Missing bundled $name font", 0, context.resources.getIdentifier(name, "font", context.packageName))
        }
        listOf("space_grotesk_OFL.txt", "inter_OFL.txt").forEach { name ->
            val license = context.assets.open("font-licenses/$name").bufferedReader().use { it.readText() }
            org.junit.Assert.assertTrue("Missing OFL notice in $name", license.contains("SIL OPEN FONT LICENSE Version 1.1"))
        }
    }

    @Test
    @Config(sdk = [26])
    fun both_variable_fonts_load_at_the_apps_minimum_api() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        listOf("space_grotesk_variable", "inter_variable").forEach { name ->
            val fontId = context.resources.getIdentifier(name, "font", context.packageName)
            assertNotEquals("Missing $name on API 26", 0, fontId)
            assertNotNull("Unable to load $name on API 26", context.resources.getFont(fontId))
        }
    }

    private fun renderedStyle(label: String): TextStyle {
        val results = mutableListOf<TextLayoutResult>()
        composeRule.onNodeWithText(label, useUnmergedTree = true)
            .performSemanticsAction(SemanticsActions.GetTextLayoutResult) { get -> get(results) }
        return results.single().layoutInput.style
    }
}
