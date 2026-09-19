package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the browser-pinning decision behind [openExternalUrl]. The regression
 * target is a device with two browsers and no default: the system resolver
 * answers with its own package, and pinning the VIEW intent to it used to
 * kill every legal / help link with a "No browser found" toast.
 */
class SoleBrowserPackageTest {

    @Test fun `single browser is pinned`() {
        assertEquals(
            "com.android.chrome",
            soleBrowserPackage(listOf("com.android.chrome"), "com.equipseva.app"),
        )
    }

    @Test fun `two browsers leave the choice to the system`() {
        assertNull(
            soleBrowserPackage(
                listOf("com.android.chrome", "org.mozilla.firefox"),
                "com.equipseva.app",
            ),
        )
    }

    @Test fun `the system resolver package is never pinned`() {
        // ResolverActivity reports package "android"; setPackage("android")
        // on a VIEW intent resolves nothing at all.
        assertNull(soleBrowserPackage(listOf("android"), "com.equipseva.app"))
    }

    @Test fun `resolver alongside one browser still pins that browser`() {
        assertEquals(
            "com.android.chrome",
            soleBrowserPackage(listOf("android", "com.android.chrome"), "com.equipseva.app"),
        )
    }

    @Test fun `our own package is dropped so the link cannot re-enter the app`() {
        // Pinning to ourselves would send the URL straight back through the
        // App Links route the caller is trying to leave.
        assertNull(soleBrowserPackage(listOf("com.equipseva.app"), "com.equipseva.app"))
        assertEquals(
            "com.android.chrome",
            soleBrowserPackage(
                listOf("com.equipseva.app", "com.android.chrome"),
                "com.equipseva.app",
            ),
        )
    }

    @Test fun `duplicate activities of one browser count once`() {
        // A browser can expose several matching activities; that must not
        // read as "several browsers installed".
        assertEquals(
            "com.android.chrome",
            soleBrowserPackage(
                listOf("com.android.chrome", "com.android.chrome"),
                "com.equipseva.app",
            ),
        )
    }

    @Test fun `no handler at all yields no package`() {
        assertNull(soleBrowserPackage(emptyList(), "com.equipseva.app"))
    }
}
