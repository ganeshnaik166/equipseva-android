package com.equipseva.app.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Engineering
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.LocalHospital
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.RoleSelectCard
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.Spacing

/**
 * N01 — "How will you use EquipSeva?" (PRODUCT_PLAN §1, page plan N01).
 *
 * **Prepared, not wired.** This composable has no route, no ViewModel and no
 * navigation; nothing in the app reaches it yet. It exists so the P3 entry
 * work can start from a reviewed, tested surface. Choosing an option is a
 * local onboarding draft ([PublicRegistrationIntent]) and nothing more: it
 * does not extend the backend role enum, issue `add_role`, claim an
 * organisation, persist an entitlement or open any workspace. The
 * "Engineering team" choice in particular grants nothing until P2 (tenants)
 * and P4 (billing) exist server-side; the copy says so.
 *
 * Semantics: the three cards form a radio group (TalkBack reads
 * "radio button, selected/not selected"); Continue is disabled until a
 * choice exists; Sign in is always available for returning users.
 */
@Composable
internal fun RegistrationIntentContent(
    selected: PublicRegistrationIntent?,
    onSelect: (PublicRegistrationIntent) -> Unit,
    onContinue: () -> Unit,
    onSignIn: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(PaperDefault),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.xl, vertical = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = stringResource(R.string.registration_intent_title),
                style = EsType.H2,
                color = SevaInk900,
            )
            Text(
                text = stringResource(R.string.registration_intent_subtitle),
                style = EsType.BodySm,
                color = SevaInk500,
                modifier = Modifier.padding(bottom = Spacing.sm),
            )
            Column(
                modifier = Modifier.selectableGroup(),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                PublicRegistrationIntent.entries.forEach { intent ->
                    val visual = intent.visual()
                    RoleSelectCard(
                        icon = visual.icon,
                        title = stringResource(visual.title),
                        description = stringResource(visual.body),
                        hue = visual.hue,
                        selected = intent == selected,
                        onSelect = { onSelect(intent) },
                    )
                }
            }
            Text(
                text = stringResource(R.string.registration_intent_note),
                style = EsType.Caption,
                color = SevaInk500,
                modifier = Modifier.padding(top = Spacing.xs),
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.xl, vertical = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            EsBtn(
                text = stringResource(R.string.registration_intent_continue),
                onClick = onContinue,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = selected == null,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.registration_intent_have_account),
                    style = EsType.BodySm,
                    color = SevaInk500,
                )
                Spacer(Modifier.width(Spacing.xxs))
                EsBtn(
                    text = stringResource(R.string.registration_intent_sign_in),
                    onClick = onSignIn,
                    kind = EsBtnKind.Ghost,
                    size = EsBtnSize.Sm,
                )
            }
        }
    }
}

private data class IntentVisual(val icon: ImageVector, val title: Int, val body: Int, val hue: Int)

/** Icon, copy and tile hue per public purpose. Hues follow the GradientTile sweep (green 150, blue 200, purple 280). */
private fun PublicRegistrationIntent.visual(): IntentVisual = when (this) {
    PublicRegistrationIntent.BIOMEDICAL_ENGINEER -> IntentVisual(
        icon = Icons.Outlined.Engineering,
        title = R.string.registration_intent_engineer_title,
        body = R.string.registration_intent_engineer_body,
        hue = 150,
    )
    PublicRegistrationIntent.HOSPITAL -> IntentVisual(
        icon = Icons.Outlined.LocalHospital,
        title = R.string.registration_intent_hospital_title,
        body = R.string.registration_intent_hospital_body,
        hue = 200,
    )
    PublicRegistrationIntent.ENGINEERING_ORGANISATION -> IntentVisual(
        icon = Icons.Outlined.Groups,
        title = R.string.registration_intent_team_title,
        body = R.string.registration_intent_team_body,
        hue = 280,
    )
}
