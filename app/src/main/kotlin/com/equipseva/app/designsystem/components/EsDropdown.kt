package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.EsColors
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsTheme
import com.equipseva.app.designsystem.theme.EsType

private class DropdownOpening {
    var query by mutableStateOf("")
    // Immediate retirement also fences duplicate callbacks before the next recomposition.
    var active = true
}

/** Controlled selection; ephemeral menu state retires at each observed context boundary. */
@Composable
fun EsDropdown(
    value: String?,
    onValueChange: (String) -> Unit,
    options: List<String>,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String = stringResource(R.string.es_dropdown_select),
    hint: String? = null,
    error: String? = null,
    enabled: Boolean = true,
    searchable: Boolean = true,
    palette: EsColors = EsTheme.colors,
) {
    // Copy so an observed in-place mutation also changes the remembered key.
    val choices = options.toList()
    var opening by remember(value, choices, enabled, searchable) { mutableStateOf<DropdownOpening?>(null) }
    val currentOpening by rememberUpdatedState(opening)
    val currentOnValueChange by rememberUpdatedState(onValueChange)
    val canExpand = enabled && choices.isNotEmpty()
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val focusRequester = remember { FocusRequester() }
    val menu = opening
    DisposableEffect(menu) { onDispose { menu?.active = false } }
    val query = menu?.query.orEmpty()
    val filtered = if (query.isBlank()) choices else choices.filter { it.contains(query, ignoreCase = true) }
    val stateLabel = stringResource(if (menu == null) R.string.es_dropdown_collapsed else R.string.es_dropdown_expanded)
    val shape = RoundedCornerShape(EsRadius.Md)
    val border = when {
        error != null -> palette.error.content
        focused -> palette.focus
        else -> palette.outline
    }
    val close: () -> Unit = {
        if (menu != null && menu.active && currentOpening === menu) {
            menu.active = false
            opening = null
            focusRequester.requestFocus()
        }
    }

    Column(modifier.fillMaxWidth()) {
        if (label != null) {
            Text(label, style = EsType.Label, color = palette.muted,
                // The trigger owns the name; avoid a separate duplicate accessibility stop.
                modifier = Modifier.padding(start = 4.dp, bottom = 6.dp).clearAndSetSemantics {})
        }
        Box {
            Row(
                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp)
                    .clip(shape).background(if (canExpand) palette.surface else palette.disabled.container)
                    .border(if (focused) 2.dp else 1.dp, border, shape)
                    .focusRequester(focusRequester)
                    .semantics {
                        contentDescription = label ?: placeholder
                        stateDescription = stateLabel
                        if (error != null) error(error)
                    }
                    .clickable(enabled = canExpand, role = Role.DropdownList,
                        interactionSource = interaction, indication = ripple()) {
                        if (opening == null) opening = DropdownOpening()
                    }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(value?.takeIf { it.isNotBlank() } ?: placeholder, style = EsType.Body,
                    color = if (!canExpand) palette.disabled.content else if (value.isNullOrBlank()) palette.muted else palette.text,
                    modifier = Modifier.weight(1f))
                Icon(Icons.Filled.ArrowDropDown, null, tint = if (canExpand) palette.muted else palette.disabled.content,
                    modifier = Modifier.size(24.dp))
            }
            DropdownMenu(
                expanded = menu != null && canExpand,
                onDismissRequest = close,
                containerColor = palette.surface,
                modifier = Modifier.fillMaxWidth(0.9f).heightIn(max = 360.dp),
            ) {
                if (searchable && choices.size > 8) {
                    OutlinedTextField(query, { text ->
                        if (menu != null && menu.active && currentOpening === menu) menu.query = text
                    }, label = { Text(stringResource(R.string.es_dropdown_search_placeholder), style = EsType.Label) },
                        singleLine = true, shape = RoundedCornerShape(EsRadius.Sm),
                        colors = esInputColors(palette), textStyle = EsType.Body,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp))
                }
                if (filtered.isEmpty()) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.es_dropdown_no_matches),
                        style = EsType.BodySm, color = palette.muted) }, onClick = {}, enabled = false)
                } else filtered.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(option, style = EsType.Body, color = palette.text) },
                        modifier = Modifier.semantics { selected = option == value },
                        onClick = {
                            if (menu != null && menu.active && currentOpening === menu) {
                                close()
                                currentOnValueChange(option)
                            }
                        },
                    )
                }
            }
        }
        (error ?: hint)?.let {
            Text(it, style = EsType.BodySm, color = if (error != null) palette.error.content else palette.muted,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp))
        }
    }
}
