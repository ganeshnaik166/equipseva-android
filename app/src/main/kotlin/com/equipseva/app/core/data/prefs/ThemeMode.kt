package com.equipseva.app.core.data.prefs

enum class ThemeMode(val storageKey: String) {
    System("system"),
    Light("light"),
    Dark("dark");

    companion object {
        fun fromKey(key: String?): ThemeMode =
            entries.firstOrNull { it.storageKey == key } ?: Light
    }
}
