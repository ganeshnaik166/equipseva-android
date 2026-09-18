package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import com.equipseva.app.R
import com.equipseva.app.core.data.moderation.ContentReportReason
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import kotlinx.coroutines.launch

/**
 * Bottom sheet that lets the user pick a reason and add optional notes before
 * a piece of content gets reported. The caller handles submit — this is a pure
 * form shell so ChatScreen / MarketplaceScreen / RepairJobDetailScreen can
 * reuse it without duplicating the picker.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportContentSheet(
    titleLabel: String,
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (reason: ContentReportReason, notes: String?) -> Unit,
) {
    // rememberModalBottomSheetState captures confirmValueChange once, so the
    // predicate has to read the flag through a state holder to see later values.
    val busy by rememberUpdatedState(submitting)
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { sheetDismissAllowed(it, busy) },
    )
    val scope = rememberCoroutineScope()
    val reasons = remember { ContentReportReason.entries }
    var selected by rememberSaveable { mutableStateOf(ContentReportReason.Spam) }
    var notes by rememberSaveable { mutableStateOf("") }

    val dismissWithAnim: () -> Unit = {
        scope.launch {
            sheetState.hide()
            onDismiss()
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = titleLabel,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                text = stringResource(R.string.report_content_safety_note),
                style = MaterialTheme.typography.bodySmall,
                color = Ink700,
            )
            // selectable on the whole row, not on the RadioButton: the reason
            // label used to be an inert sibling, so tapping the words did
            // nothing and TalkBack announced an unnamed "radio button, not
            // checked" because the label was never merged into the control.
            Column(
                modifier = Modifier.fillMaxWidth().selectableGroup(),
            ) {
                reasons.forEach { reason ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .selectable(
                                selected = selected == reason,
                                enabled = !submitting,
                                role = Role.RadioButton,
                                onClick = { selected = reason },
                            )
                            .minimumInteractiveComponentSize()
                            .padding(vertical = Spacing.xs),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        RadioButton(
                            selected = selected == reason,
                            // null: the row owns the click so the control is not
                            // a second, separately announced stop.
                            onClick = null,
                            enabled = !submitting,
                        )
                        Text(
                            text = reason.displayName,
                            style = MaterialTheme.typography.bodyLarge,
                            color = Ink900,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
            OutlinedTextField(
                value = notes,
                onValueChange = { if (it.length <= 1000) notes = it },
                label = { Text(stringResource(R.string.report_content_notes_label)) },
                supportingText = { Text(stringResource(R.string.report_content_notes_count, notes.length)) },
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
                minLines = 2,
                maxLines = 4,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                TextButton(
                    onClick = dismissWithAnim,
                    enabled = !submitting,
                    modifier = Modifier.weight(1f),
                ) { Text(stringResource(R.string.common_cancel)) }
                PrimaryButton(
                    label = if (submitting) "Submitting…" else "Submit report",
                    onClick = { onSubmit(selected, notes.trim().ifEmpty { null }) },
                    enabled = !submitting,
                    loading = submitting,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}
