# UI-02 shared inputs — working contract (2026-09-13)

Base: `75e55c14730d6f3499d34bbcc7155e994f0f8816`, branch `codex/auth-integration-20260911`.
Scope: `EsField`, `EsDropdown`, their synthetic tests and minimal caller compatibility.
OTP, navigation, auth repositories, account ownership and page redesigns are outside this slice.

## Contract frozen before implementation

- Use the approved lime/ink palette, Inter body 16/24, labels 14/20 semibold, supporting copy 14/20, 16dp corners. Input/trigger areas have a 56dp minimum and grow with content. Error and label text must remain complete at 2x font size and 320dp in English, Hindi and Telugu.
- Pair text, surface, placeholder, disabled, error, focus, selection, icon and popup colors. A complete caller inventory found 57 fields and 3 dropdowns in 22 files: 48 fields and all dropdowns are on fixed light surfaces; 9 fields are in themed Material dialogs/sheets. Explicit compatibility palettes preserve these parents until their page batch.
- Associate durable names and exact errors with the editable/actionable node. Preserve password/editing semantics and native keyboard behavior. No password values in descriptions, persistence, normalization or new submission policy. Next advances focus; Done/Send/Go/Search retain optional callbacks. Sign-up Done remains non-submitting.
- Preserve the two deliberately disabled time displays whose outer click opens a time picker, the bid ETA focus listener, numeric filters, KYC district cascade and AddressForm state/city policy. The component must not clear/choose a controlled value.
- Dropdown open/search state belongs to a specific observed value/options/enabled/searchable context and a specific opening. Disable, empty options, changed options/value or searchable mode retires it. Re-enable requires a new gesture. A stale menu callback cannot emit into a later opening; a fresh selection emits its exact value once. Search disappears without leaving a hidden filter, and dismissal clears it.
- Keep the native focusable popup and reachable keyboard options. Test hardware-style key dispatch separately from IME semantics. Repository identity boundaries that cause no observed component change are not solved by this UI slice.

## Evidence and acceptance

`SharedInputContractTest` is added before production edits. Preserve the actual red command/results, including test-harness corrections. Follow with native rendering/large text, lifecycle/keyboard/password contracts, targeted tests, full unit/lint/debug/unsigned release checks, independent critic and QA review. A score applies only to this slice and observed evidence. Device/TalkBack/OEM IME, provider/integration and signed-release acceptance remain separate.

Local build reservation: `outputs/equipseva-build-slot.md`; no competing Gradle process.
Raw evidence directory: `work/verification/ui-inputs-20260913` (outside the repository).

Primary references: [Compose semantics](https://developer.android.com/develop/ui/compose/accessibility/semantics), [native menus](https://developer.android.com/develop/ui/compose/components/menu), [text input](https://developer.android.com/develop/ui/compose/text/user-input).

## Implementation decisions and preserved failures

- The initial 10-test baseline failed eight tests; one was an invalid disabled-node selector. Correcting only that selector produced **10 tests / 7 real failures** on unchanged production. Raw logs/XML are retained.
- The first implementation closed all seven baseline defects. A stronger native IME test incorrectly required `TYPE_TEXT_FLAG_NO_SUGGESTIONS`: Compose omits `AUTO_CORRECT` when autocorrect is false, rather than setting that extra bit. The final test compares actual `EditorInfo` with an unchanged baseline fixture: password `0x81`, email `0x21`; correct variations and no autocorrect/capitalization flags. No OEM suggestion-cache guarantee is claimed. [AndroidX bridge source](https://android.googlesource.com/platform/frameworks/support/+/c4b0af2cf608b0ee1d5542627f3c1358bbd956ac/compose/ui/ui/src/androidMain/kotlin/androidx/compose/ui/text/input/TextInputServiceAndroid.android.kt)
- Native popup keyboard tests must configure the new window's global input mode. Escape is delivered to the real `PopupLayout`, above the Compose child targeted by key injection. Enter, arrow traversal, native Escape, return focus and searched-menu dismissal remain executable checks; the earlier failure is retained. [Robolectric window setup](https://raw.githubusercontent.com/robolectric/robolectric/robolectric-4.16.1/shadows/framework/src/main/java/org/robolectric/shadows/ShadowWindowManagerGlobal.java)
- Native floating labels escaped their component at 2x text, including the compact payout row. Labels now remain above the outline and grow normally. The editable node owns their accessible name; visible label semantics are hidden only from accessibility. Native editing, selection and support rendering remain intact. The payout card already names minimum net payout, so its new field label is the shorter localized **Amount (₹)**.
- The two quiet-hour actions were unnamed while their disabled child displays had labels. A small `QuietHourField` now exposes one enabled, named button, preserving actual time-picker closures and disabled display behavior. Synthetic tests tap inside its physical input area and exercise its accessibility action.
- The nine themed dialog/sheet inputs inherit the active palette. All fixed-light input instances retain complete explicit compatibility palettes. The two quiet-hour instances now share one local wrapper; the original 57+3 inventory refers to instances before extraction.

After these corrections: **36 non-popup tests passed together**, including actual placeholder/icon/selection pixels; **all three popup tests passed separately**. Their unchanged finite-frame caret assertion needed the real popup window-activation event, which Robolectric does not deliver automatically. This setup is restored at teardown. Popup option/search/empty-state fills and glyphs are measured from the popup's own view, including native caret frames. The final combined full build and independent reviews are pending; no acceptance score yet.

Independent review requested two additional size gates. A 640×320/2x field-and-popup scenario and Hindi/Telugu 320dp/2x popup cases passed, with scrolling, actual selection, label/option containment and native pixel checks. This brings the new component coverage to **43 tests**. The first frozen source passed the full 3,194-test/lint/debug/unsigned-release bar; the added test-only revision receives a final full bar before acceptance. No production workaround was needed for these size probes.
