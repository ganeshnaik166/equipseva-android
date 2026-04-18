package com.equipseva.app.designsystem.components

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun QuantityStepper(
    value: Int,
    onDecrement: () -> Unit,
    onIncrement: () -> Unit,
    modifier: Modifier = Modifier,
    min: Int = 1,
    max: Int = 99,
) {
    val scheme = MaterialTheme.colorScheme
    Surface(
        modifier = modifier.height(40.dp),
        shape = CircleShape,
        color = scheme.surface,
        contentColor = scheme.onSurface,
        border = null,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
            modifier = Modifier
                .border(1.dp, scheme.outline, CircleShape)
                .padding(horizontal = 4.dp),
        ) {
            IconButton(
                onClick = onDecrement,
                enabled = value > min,
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    imageVector = Icons.Outlined.Remove,
                    contentDescription = "Decrease",
                )
            }
            Text(
                text = value.toString(),
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .width(28.dp)
                    .padding(horizontal = 2.dp),
            )
            IconButton(
                onClick = onIncrement,
                enabled = value < max,
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    imageVector = Icons.Outlined.Add,
                    contentDescription = "Increase",
                )
            }
        }
    }
}
