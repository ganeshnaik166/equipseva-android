package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

// Six individual digit boxes for OTP entry. A single hidden BasicTextField captures input;
// the visual is rendered as 6 boxes that auto-advance focus + show error state.
@Composable
fun OtpDigitField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    length: Int = 6,
    error: String? = null,
) {
    val isError = error != null
    Column(modifier = modifier.fillMaxWidth()) {
        Box {
            BasicTextField(
                value = value.take(length),
                onValueChange = { new ->
                    val cleaned = new.filter { it.isDigit() }.take(length)
                    onValueChange(cleaned)
                },
                // The visual 6-box row above is decorative; the only
                // tappable / typable element is this hidden BasicTextField.
                // TalkBack needs an explicit content description + a
                // stateDescription that announces typed/total digits, plus
                // an error semantics signal so screen-reader users hear
                // "code is incorrect" not just see red borders.
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .alpha(0f)
                    .semantics {
                        contentDescription = "One-time code, $length digits"
                        stateDescription = "${value.length} of $length digits entered"
                        // `error` is captured locally so the smart-cast
                        // survives across the lambda boundary; without it
                        // Kotlin can't prove non-null in the `error()` call.
                        val errText = error
                        if (errText != null) error(errText)
                    },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                singleLine = true,
                cursorBrush = SolidColor(BrandGreen),
                textStyle = TextStyle(color = Ink900),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                repeat(length) { index ->
                    val char = value.getOrNull(index)?.toString() ?: ""
                    val isFocusedBox = index == value.length.coerceAtMost(length - 1)
                    val borderColor = when {
                        isError -> ErrorRed
                        isFocusedBox -> BrandGreen
                        else -> Surface200
                    }
                    val bg = if (isFocusedBox && !isError) BrandGreen50 else Surface0
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(bg)
                            .border(
                                width = if (isFocusedBox || isError) 2.dp else 1.dp,
                                color = borderColor,
                                shape = RoundedCornerShape(8.dp),
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = char,
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontSize = 22.sp,
                                fontWeight = FontWeight.SemiBold,
                                textAlign = TextAlign.Center,
                            ),
                            color = Ink900,
                        )
                    }
                }
            }
        }
        if (error != null) {
            Spacer(Modifier.height(Spacing.xs))
            // liveRegion = Polite so the screen reader announces the
            // error the moment it appears without interrupting the user
            // mid-typing. Without this, TalkBack users only learn the
            // code was wrong on the next focus traversal.
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = ErrorRed,
                modifier = Modifier.semantics {
                    liveRegion = LiveRegionMode.Polite
                },
            )
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun OtpDigitFieldGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Empty", style = MaterialTheme.typography.labelSmall)
        OtpDigitField(value = "", onValueChange = {})
        Text("Partially entered", style = MaterialTheme.typography.labelSmall)
        OtpDigitField(value = "482", onValueChange = {})
        Text("Complete", style = MaterialTheme.typography.labelSmall)
        OtpDigitField(value = "482913", onValueChange = {})
        Text("Error", style = MaterialTheme.typography.labelSmall)
        OtpDigitField(
            value = "482913",
            onValueChange = {},
            error = "Incorrect code. Please try again.",
        )
        Text("Error, long message", style = MaterialTheme.typography.labelSmall)
        OtpDigitField(
            value = "48",
            onValueChange = {},
            error = "This code has expired. Request a new code for +91 98765 43210 " +
                "and enter it within 10 minutes.",
        )
        Text("4 digits", style = MaterialTheme.typography.labelSmall)
        OtpDigitField(value = "73", onValueChange = {}, length = 4)
    }
}

@Preview(name = "OtpDigitField", showBackground = true)
@Composable
private fun OtpDigitFieldPreview() {
    EquipSevaTheme(darkTheme = false) { OtpDigitFieldGallery() }
}

@Preview(name = "OtpDigitField large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun OtpDigitFieldPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { OtpDigitFieldGallery() }
}
