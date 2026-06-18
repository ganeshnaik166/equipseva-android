# EquipSeva Anti-Mod Defense Stack

> 15-layer defense matrix protecting against modded / repackaged / sideloaded APKs.
> Shipped r422-r979 with major hardening sprint at r843-r856 (June 2026)
> + r979 foreground re-verify (added 2026-06-18).

## Threat model

An attacker who:

1. Downloads the APK from a third-party store or via APK extractor on a real device.
2. Decompiles with `apktool` / `jadx` to study the code.
3. Patches one or more Kotlin code paths (signature check, KYC bypass, payment skip).
4. Re-signs with their own keystore.
5. Distributes via WhatsApp / direct download / clone store.

The stack below makes the patch-and-redistribute attack progressively harder. No layer alone is sufficient; the point is that each layer the attacker has to defeat takes hours, and patches accumulate cost.

## Layers (in order of cost-to-bypass, ascending)

### 1. R8 minify + obfuscate (release builds only)

`app/build.gradle.kts` sets `isMinifyEnabled = true` + `isShrinkResources = true` on `release`. Kotlin class names, method names, field names collapsed to `a`/`b`/`c`. Dead code dropped. Resource references mangled.

**Defeats:** casual decompile-and-read. A serious attacker still gets through but spends 10x longer mapping symbols.

### 2. Certificate pinning (supabase.co + razorpay.com)

`app/src/main/res/xml/network_security_config.xml` pins both the intermediate CA and a backup root for each domain. Pin set expires 2027-12-31.

**Defeats:** MITM via a rogue corporate CA or user-installed certificate. The attacker would need to compromise Google Trust Services or DigiCert directly.

### 3. User-installed CAs rejected + cleartext blocked

Same network security config: `cleartextTrafficPermitted="false"` and `<trust-anchors><certificates src="system" /></trust-anchors>` (no `user` source).

**Defeats:** Burp Suite / mitmproxy on rooted phones.

### 4. Signature SHA-256 check at boot

`SignatureVerifier.kt` reads the running APK's signing certificate, hashes it, compares against the `EXPECTED_CERT_SHA256` allow-list compiled into the build via `BuildConfig`.

**Defeats:** re-signed APKs (which is what `apktool b ... && apksigner sign` produces).

### 5. Hard-exit on tamper (`TAMPER_ENFORCE=true`)

When the build was made with `TAMPER_ENFORCE=true` in CI secrets AND the signature check returns `Tampered`, `EquipSevaApplication.onCreate` calls `Process.killProcess(myPid())` BEFORE any auth/network code runs.

**Defeats:** an attacker who modded the signature check itself would still hit this earlier exit unless they also patched onCreate.

### 6. DeviceIntegrityCheck — root/emu/Frida/debugger probes

`DeviceIntegrityCheck.kt` runs at boot:

- Magisk binary file probes (`/system/xbin/su`, `/data/adb/magisk`, etc.)
- Emulator detection (`Build.FINGERPRINT` startsWith `generic`/`unknown`/`vbox`)
- Frida default port (`127.0.0.1:27042`) connect probe
- Debugger attached (`Debug.isDebuggerConnected()`)

**Defeats:** the most common Android-side dynamic analysis setups.

### 7. Dev-mode hard block

In release builds, if either `DEVELOPMENT_SETTINGS_ENABLED` or `ADB_ENABLED` is on, `DeviceIntegrityCheck.Verdict.devModeBlocking` returns true and `DevModeBlockingScreen` replaces the UI.

**Defeats:** USB-debugging-based instrumentation.

### 8. Play Integrity API + server attestation

`PlayIntegrityClient.kt` calls Google's `requestIntegrityToken()`. The server-side `verify-play-integrity` edge function exchanges the token with Google's `decodeIntegrityToken` endpoint and returns a `pass`/`fail` based on `deviceIntegrity.deviceRecognitionVerdict`.

This is Google's official attestation — bypassing it requires defeating Google Play Services on-device or compromising Google's signing keys.

**Defeats:** essentially everything client-side.

### 9. Encrypted session storage (Keystore-backed)

`EncryptedSessionManager.kt` overrides Supabase's default `SettingsSessionManager` with `EncryptedSharedPreferences` keyed by the Android Keystore (AES256/GCM). Session tokens are never on disk in plaintext.

**Defeats:** an attacker who extracts `/data/data/com.equipseva.app/shared_prefs` (e.g. via `adb backup` on a rooted device) cannot replay the session.

### 10. Manifest hardening (`extractNativeLibs=false` + `allowBackup=false`)

- `extractNativeLibs=false`: native libs stay inside the APK; can't be tampered after install.
- `allowBackup=false`: `adb backup -apk com.equipseva.app` returns empty; session storage never leaves the device.

### 11. **r843** InstallSourceVerifier — non-Play installer blocked

`InstallSourceVerifier.kt` reads `PackageManager.getInstallSourceInfo().installingPackageName`. Allow-list: `com.android.vending` (Play Store), `com.google.android.feedback` (Play Store update channel). `com.android.shell` (ADB) is mapped to `AdbSideload`. Anything else → `Sideloaded`.

When `TAMPER_ENFORCE=true` and verdict is `Sideloaded` in release, the process exits.

**Defeats:** APK downloaded from a clone store / direct link, installed via that store's installer.

### 12. **r843** ReverseEngineeringDetector — known hooking frameworks

`ReverseEngineeringDetector.kt` calls `getPackageInfo(pkg, 0)` for ~20 known package IDs:

- Xposed / LSPosed family (`de.robv.android.xposed.installer`, `org.lsposed.manager`, etc.)
- LSPatch (`org.lsposed.lspatch`)
- Magisk Manager (`com.topjohnwu.magisk`)
- Frida server / Substrate
- Lucky Patcher, Game Guardian, packet capture tools

If any are installed, in release with `TAMPER_ENFORCE=true`, process exits.

**Defeats:** active hooking frameworks on the same device.

### 13. **r844** `X-Equipseva-Integrity` header on every Supabase request

`SupabaseModule.kt` installs a ktor `defaultRequest` plugin that stamps every outbound request with the boot-time integrity snapshot (`sig=ok|tampered, install=playstore|sideloaded, re=N, root=1, frida=1, dbg=1`). Server persists it (r846) into `device_integrity_checks.client_integrity_header` for every Play Integrity call. `/security-overview` and `/integrity-events` surface dirty headers.

**Defeats:** a partial mod that strips the boot-time hard-exit but doesn't also patch the snapshot — the header still flags the client as dirty server-side. The edge-fn gate (r851, `_shared/integrity_gate.ts`) can refuse payment-order creation outright when `EDGE_INTEGRITY_ENFORCE=true`.

### 14. **r845** Periodic 15-min re-verify

A coroutine launched from `appScope` re-runs all checks every 15 minutes. If any verdict flips dirty mid-session (e.g. user installs Frida after launch), it exits.

**Defeats:** an attacker who passed the boot check then enabled tampering.

### 15. **r979** Foreground re-verify

A `DefaultLifecycleObserver` registered on `ProcessLifecycleOwner.get().lifecycle` re-runs all 4 integrity checks (SignatureVerifier, InstallSourceVerifier, ReverseEngineeringDetector, DeviceIntegrityCheck) on every `onStart` event of the app process — i.e. every time the user brings the app from background to foreground.

Catches the case where the user backgrounded the app and the device was tampered with mid-session (USB debugging enabled, Frida installed, LSPosed sideloaded) between background → next foreground. Cheaper than the 15-min r845 timer because it runs only on transition, not periodically.

Also refreshes the `X-Equipseva-Integrity` header (r844 via `IntegritySnapshot.capture`) so subsequent Supabase requests carry the fresh device state, not just boot-time state.

**Defeats:** mid-session tamper that happened while the app was backgrounded. With r845 (timer) and r979 (foreground transition), an attacker has 3 verify checkpoints (boot, foreground, 15-min) to defeat from a single patch.

## Enforcement state

| Variable | Where | Effect |
|----------|-------|--------|
| `EXPECTED_CERT_SHA256` | `BuildConfig` via `local.properties` / CI secret | Comma-separated allow-list of signing-cert SHA-256 fingerprints |
| `TAMPER_ENFORCE` | Same | When `true`, layers 5/11/12 hard-exit on dirty verdict |
| `EDGE_INTEGRITY_ENFORCE` | Supabase edge fn env (`supabase secrets set ...`) | When `true`, layer 13 server-side gate refuses payment-order creation from dirty clients |

Default: all flags false → all layers run in **observe-only** mode, writing logs + the per-request header but never blocking. Flip to enforce only after Play App Signing SHA is added to `EXPECTED_CERT_SHA256`.

## To go live

1. Upload first AAB to Google Play Console.
2. Play Console → App signing → grab the Play App Signing certificate SHA-256.
3. `supabase secrets set EXPECTED_CERT_SHA256=<upload-key-sha>,<play-app-signing-sha>` (comma-separated).
4. `supabase secrets set TAMPER_ENFORCE=true`.
5. Optionally: `supabase secrets set EDGE_INTEGRITY_ENFORCE=true`.
6. Ship a new release. Re-signed / sideloaded / RE-tool-installed APKs now hard-exit before any code runs.

## Auditing

- `/security-overview` (r850) — live status of all 14 layers + Play Integrity 7/30/90d summary + recent dirty events.
- `/integrity-events` (r846) — every Play Integrity call's audit row, including the client self-report header.
- `/grants-audit` (r852) — verifies founder_* RPC EXECUTE privileges, catches the r847-r849 grant bug pattern.
