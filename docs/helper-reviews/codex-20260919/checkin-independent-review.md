# Independent M6 and Compose alignment review

Read-only review. No source/test changes, build, staging or commits performed.

## M6: empty before-photo admission

Reviewed production commit `d8e3c77af053a3c65c6d202495c3270e0eec0c57` and prior test commit `5b49a6638977ecaa0196136cfa7429508fcba130`. **No introduced correctness or security blocker found for this narrow change. Scope score: 9.5/10 for the empty-list admission implementation plus its executed synthetic evidence. This is not an app, complete photo pipeline, device or release score.**

The guard in `RepairJobDetailViewModel.kt:694-706` runs after the existing job/engineer/status/busy admission gates but before the busy flag, auth lookup, stash writes, location request or check-in RPC. Rejection emits actionable photo-specific feedback and leaves the existing selection sheet open and idle. The existing valid nonempty path is unchanged. The new comment correctly withdraws the old claim that a UI gate removes the need for server enforcement.

The new test drives the real ViewModel through real initial loading and explicitly proves the assigned job and engineer state before acting, so its negative checks are not satisfied by an unrelated admission failure. It opens the real ViewModel sheet state and subscribes to messages before submission. It checks zero GPS/stash/check-in calls, unchanged job status, open sheet, idle busy flag and one photo-related message. Existing nonempty before/after cases remain present and passing. ViewModel scope cleanup and static-mock cleanup are retained.

The exact test-file Git blob is identical at red and fix commits: `da2da7739724457993ee122c05d2f140c90fe413`. No assertion was weakened between the demonstrated red and green.

Verified XML evidence:

- `fixes-target-2-xml/TEST-com.equipseva.app.features.repair.RepairPhotoEvidenceContractTest.xml`: **5 tests, 1 failure, 0 errors, 0 skipped**. The new target fails because `fetchCurrentLocation` was called despite empty input. Its later state assertions are not claimed as executed in that red run; the sheet-closing behavior is also visible in pre-fix source.
- `ui-photo-target-3-xml/TEST-com.equipseva.app.features.repair.RepairPhotoEvidenceContractTest.xml`: **5 tests, 0 failures, 0 errors, 0 skipped**. All five case names remain present.
- The enclosing `ui-photo-target-3.log` is **not green overall**: 11 tests, 3 failures in the separate shared UI class. M6's class passing must not be reported as that whole Gradle invocation passing.

Limits/polish: the sheet uses `ContentResolver.readBytes()` and `mapNotNull`, not an image decoder, so the proven input is an empty successfully-read photo list; this is not image-format validation. Content-provider errors/cancellation, real photo selection and on-device retry, durable upload completion, account-switch ownership and server evidence authorization are outside this test. The new error text is a hardcoded English ViewModel message, consistent with surrounding messages but still a locale polish follow-up. No tests were deleted or ignored.

## Compose alignment: a83dbedb

Reviewed `a83dbedb776b131b068b234120a44af73046a483`: the app changes the Compose BOM from `2024.12.01` to `2025.08.00` and uses `implementation(enforcedPlatform(...))`. Supabase/Firebase platforms, repositories, signing settings and security gates are untouched.

The saved pre-fix dependency reports support the claimed mismatch: `compose-classpaths.log` shows compile `foundation-layout` 1.7.6; `compose-app-runtime-dependency.log` shows runtime 1.9.0. The cached 2025.08.00 BOM POM explicitly aligns foundation/layout, UI, tooling and UI tests at 1.9.0 and Material3 at 1.3.2. The Kotlin Compose compiler plugin remains tied to the existing Kotlin 2.3.21 version. This is an application module, so the principal risk of exporting forced constraints to downstream library consumers does not apply here.

No obvious newly introduced build/security defect found from the dependency declarations. The aligned BOM is a plausible correction for an actual binary API mismatch, not a security-gate bypass. `OtpRenewalDismissalTest` in `fixes-target-2-xml` records **3 tests, 0 failures, 0 skipped**, supporting the narrow runtime linkage repair.

Broader acceptance remains pending: this changes the Compose foundation/UI runtime across the app and can alter layout, semantics and screenshots. Run full unit/lint/debug/release checks and the Linux screenshot gate; also inspect final debug/release and test compile/runtime resolution if a mismatch remains. Enforced platforms deliberately override transitive version requests, so future Compose security/version upgrades must update the chosen BOM instead of relying on a transitive upgrade. This review did not perform a vulnerability advisory scan or claim the dependency set is CVE-free.

Evidence warning: `compose-aligned-runtime.log` is from the earlier **2024.12.01 / 1.7.6** forced experiment, not a post-a83dbedb 2025.08.00 resolved-classpath proof. Do not present that file as final-resolution evidence.
