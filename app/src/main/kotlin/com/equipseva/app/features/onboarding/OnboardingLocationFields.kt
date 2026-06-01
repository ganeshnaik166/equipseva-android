package com.equipseva.app.features.onboarding

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import com.equipseva.app.core.data.location.IndiaLocations

/**
 * Shared State + District inputs used by both onboarding flows (hospital
 * + engineer). Same UX: state is a single dropdown over [IndiaLocations.STATES];
 * district is a dropdown when bundled data exists for the picked state,
 * otherwise a free-text fallback so users in uncovered states (Bihar, UP, …)
 * can still progress without being blocked on data we haven't shipped yet.
 *
 * Why shared: both onboarding screens capture the exact same address pair,
 * with the same picker semantics. Duplicating ~80 LOC across screens was
 * the bigger risk — a future tweak to the dropdown (clearing district on
 * state change, switching to autocomplete, …) would need to land in both
 * places to stay consistent.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingStateDropdown(
    value: String,
    enabled: Boolean,
    onValueChange: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { if (enabled) expanded = it },
    ) {
        OutlinedTextField(
            value = value,
            onValueChange = { /* readOnly */ },
            label = { Text("State") },
            readOnly = true,
            enabled = enabled,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .menuAnchor(MenuAnchorType.PrimaryNotEditable, enabled)
                .fillMaxWidth(),
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            IndiaLocations.STATES.forEach { st ->
                DropdownMenuItem(
                    text = { Text(st) },
                    onClick = {
                        onValueChange(st)
                        expanded = false
                    },
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingDistrictField(
    value: String,
    options: List<String>,
    enabled: Boolean,
    onValueChange: (String) -> Unit,
) {
    if (options.isNotEmpty()) {
        var expanded by remember { mutableStateOf(false) }
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { if (enabled) expanded = it },
        ) {
            OutlinedTextField(
                value = value,
                onValueChange = { /* readOnly */ },
                label = { Text("District") },
                readOnly = true,
                enabled = enabled,
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable, enabled)
                    .fillMaxWidth(),
            )
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
            ) {
                options.forEach { d ->
                    DropdownMenuItem(
                        text = { Text(d) },
                        onClick = {
                            onValueChange(d)
                            expanded = false
                        },
                    )
                }
            }
        }
    } else {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            label = { Text("District") },
            singleLine = true,
            enabled = enabled,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            modifier = Modifier.fillMaxWidth(),
            supportingText = {
                if (enabled) {
                    Text("Type your district (we don't have a list for this state yet).")
                }
            },
        )
    }
}
