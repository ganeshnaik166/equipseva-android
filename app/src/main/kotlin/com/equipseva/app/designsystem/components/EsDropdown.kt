package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

/**
 * Searchable dropdown picker matching `<Field>` styling. Tap the field to
 * open a panel of options; type-to-filter when the menu is open. Empty
 * options list hits the disabled state so cascading pickers don't show a
 * useless menu while a parent is unselected.
 */
@Composable
fun EsDropdown(
    value: String?,
    onValueChange: (String) -> Unit,
    options: List<String>,
    label: String? = null,
    placeholder: String = "Select",
    hint: String? = null,
    error: String? = null,
    enabled: Boolean = true,
    searchable: Boolean = true,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    var query by remember(value) { mutableStateOf("") }
    val canExpand = enabled && options.isNotEmpty()
    val filtered = remember(query, options) {
        if (query.isBlank()) options
        else options.filter { it.contains(query, ignoreCase = true) }
    }

    Column(modifier = modifier.fillMaxWidth()) {
        if (label != null) {
            Text(
                text = label,
                style = EsType.Label,
                color = SevaInk500,
                modifier = Modifier.padding(start = 4.dp, bottom = 6.dp),
            )
        }
        Box {
            // Display field — read-only chip-like surface that opens the menu
            // on tap. Mirrors EsField styling.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(EsRadius.Md))
                    .border(
                        width = 1.dp,
                        color = if (error != null) SevaDanger500 else BorderDefault,
                        shape = RoundedCornerShape(EsRadius.Md),
                    )
                    .background(if (canExpand) androidx.compose.ui.graphics.Color.White else Paper2)
                    .clickable(enabled = canExpand) { expanded = true }
                    .padding(horizontal = 14.dp, vertical = 14.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = value?.takeIf { it.isNotBlank() } ?: placeholder,
                        fontSize = 14.sp,
                        color = if (value.isNullOrBlank()) SevaInk500 else SevaInk900,
                    )
                    Icon(
                        imageVector = Icons.Filled.ArrowDropDown,
                        contentDescription = null,
                        tint = SevaInk500,
                    )
                }
            }
            DropdownMenu(
                expanded = expanded && canExpand,
                onDismissRequest = {
                    expanded = false
                    query = ""
                },
                modifier = Modifier
                    .fillMaxWidth(0.9f)
                    .heightIn(max = 360.dp),
            ) {
                if (searchable && options.size > 8) {
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        placeholder = { Text("Search…", style = EsType.Caption, color = SevaInk500) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
                        shape = RoundedCornerShape(EsRadius.Sm),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SevaGreen700,
                            focusedTextColor = SevaInk900,
                            unfocusedTextColor = SevaInk900,
                        ),
                        textStyle = EsType.Body,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                    )
                }
                if (filtered.isEmpty()) {
                    DropdownMenuItem(
                        text = { Text("No matches", style = EsType.Caption, color = SevaInk500) },
                        onClick = {},
                        enabled = false,
                    )
                } else {
                    filtered.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option, style = EsType.Body, color = SevaInk900) },
                            onClick = {
                                onValueChange(option)
                                expanded = false
                                query = ""
                            },
                        )
                    }
                }
            }
        }
        val belowText = error ?: hint
        if (belowText != null) {
            Text(
                text = belowText,
                style = EsType.Caption,
                color = if (error != null) SevaDanger500 else SevaInk500,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp),
            )
        }
    }
}
