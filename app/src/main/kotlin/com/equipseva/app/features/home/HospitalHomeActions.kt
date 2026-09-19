package com.equipseva.app.features.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.style.TextAlign
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Spacing

/**
 * Navigation only. The caller mounts this for the hospital workspace; these
 * callbacks neither create a job nor imply an engineer has been assigned.
 * No counts or first-job claims depend on Home's best-effort fetches.
 */
@Composable
internal fun HospitalHomeActions(
    onRequestService: () -> Unit,
    onOpenBookings: () -> Unit,
    onBrowseEngineers: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(EsRadius.Md)
    // Script-safe font padding prevents tall Devanagari/Telugu glyphs from
    // being clipped at large system font scales without changing app-wide type.
    val labelStyle = EsType.Label.copy(platformStyle = PlatformTextStyle(includeFontPadding = true))
    val headingStyle = EsType.H2.copy(platformStyle = PlatformTextStyle(includeFontPadding = true))
    val bodyStyle = EsType.Body.copy(platformStyle = PlatformTextStyle(includeFontPadding = true))
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(EsRadius.Lg),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = stringResource(R.string.home_actions_hospital_workspace),
                style = labelStyle,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = stringResource(R.string.home_actions_title),
                style = headingStyle,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                text = stringResource(R.string.home_actions_body),
                style = bodyStyle,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            // Shared actions use a minimum height and let translated labels
            // wrap at large system font scales.
            PrimaryButton(
                label = stringResource(R.string.home_actions_request_service),
                onClick = onRequestService,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedButton(
                onClick = onOpenBookings,
                modifier = Modifier.fillMaxWidth().heightIn(min = Spacing.MinTouchTarget),
                shape = shape,
                contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.onSurface,
                ),
            ) {
                Text(
                    text = stringResource(R.string.home_actions_my_bookings),
                    style = labelStyle,
                    textAlign = TextAlign.Center,
                )
            }
            EsBtn(
                text = stringResource(R.string.home_actions_browse_engineers),
                onClick = onBrowseEngineers,
                kind = EsBtnKind.Ghost,
                size = EsBtnSize.Sm,
                full = true,
            )
        }
    }
}
