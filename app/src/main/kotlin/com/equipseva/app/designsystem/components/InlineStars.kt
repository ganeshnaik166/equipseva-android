package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaWarning500

/**
 * Compact rating + count chip used across the directory row, the
 * EngineerPublicProfile rating card, and any future surface that needs
 * the "★ 4.8 (57)" treatment. Promoted from a file-internal helper in
 * EngineerDirectoryScreen so the new EngineerRatingCard / ReviewItem
 * components can render an identical glyph without forking the
 * implementation.
 */
@Composable
fun InlineStars(rating: Double, count: Int, small: Boolean = false) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Star,
            contentDescription = null,
            tint = SevaWarning500,
            modifier = Modifier.size(if (small) 11.dp else 13.dp),
        )
        Text(
            text = "%.1f".format(rating),
            color = SevaInk700,
            fontSize = if (small) 11.sp else 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = "($count)",
            color = SevaInk400,
            fontSize = if (small) 11.sp else 12.sp,
        )
    }
}
