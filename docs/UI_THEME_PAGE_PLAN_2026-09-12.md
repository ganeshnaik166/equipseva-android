# EquipSeva: Lime / Ink UI plan

Status: **approved plan; staged implementation underway**. The owner chose
the reference palette and typography on 12 September 2026. This document freezes
the implementation sequence and the contract every page must satisfy. UI-01 and
the UI-02 shared-action slice are locally accepted at `c7da5ee3`; see the
[foundation evidence](evidence/ui-foundation/README.md). Shared text fields and
dropdowns are now locally accepted at `694bf690` (critic 9.595, QA 9.58; 3,198
tests passed); see [input evidence](evidence/ui-inputs/README.md). Remaining components,
pages and device/release acceptance stay open. The source registry below retains
its recorded planning baseline; those hashes are not a current-code inventory.

Source baseline: `1dc9188e212ab217393e055b4c238b18c72521ae`, branch
`codex/auth-integration-20260911`. Fetch confirmed the same upstream tip during
planning. `origin/main` was `fe4637568059e49f27fb46f8627fe56bccc45e27`.
The current checkout and all other worktrees are preserved.

Independent critic and documentation QA found no remaining must-fix in the
completed planning package. See [the scoped review receipt](ui-renewal/plan-review.md).
This establishes readiness to start implementation, not a rendered-app rating.

## 1. Design decision

Use the supplied `d48118db688b33ec0487dcfbf95f4306.jpg` and
`a53d0e0100080ac2ec52c1bb3de431b4.jpg` as visual references: lime actions, near-black
ink, soft white work surfaces, generous cards and pill-shaped primary controls.
The exact hex values below are our proposed product interpretation of compressed
reference images, not an assertion of the original designers' exact tokens.

Preserve the original EquipSeva logo, proportions and internal colors. Its green
mark lives on an uncluttered surface. Do not recolor the asset to the new lime.
Do not copy the references' investment/taxi copy, phone hardware, maps, rewards,
tiny captions or unlabeled bottom navigation into this medical-equipment product.

Space Grotesk is the heading family. Inter is the body and control family.
The owner's supplied title, body and label sizes are binding. Shape, secondary
roles, surface pairings and spacing below fill in the rest of the system.
This decision supersedes the old green-primary visual direction and 5dp-everywhere
shape rules in older UX documents. Existing product/security requirements remain.

### Color roles

| Role | Light | Dark | Usage |
| --- | --- | --- | --- |
| Canvas | `#F4F5F2` | `#0C0F0B` | Scrolling page background |
| Surface | `#FFFFFF` | `#1B2018` | Cards, forms, menus |
| Raised / secondary surface | `#EBEEE7` | `#282E23` | Grouped fields and supporting panels |
| Primary text | `#11150F` | `#F5F7F1` | Titles, body, key amounts |
| Secondary text | `#555D50` | `#B9C2B1` | Supporting information, not disabled essential copy |
| Primary action / selected fill | `#C6FF00` | `#C6FF00` | One dominant action; selected controls |
| On primary | `#11150B` | `#11150B` | All text/icons on lime |
| Inverse feature panel | `#11150F` with `#F5F7F1` text | Same pair | Optional home/earnings summary, never every card |
| Meaningful field/control outline | `#6D7566` | `#86947B` | Inputs and boundaries needed to identify controls |
| Decorative divider | `#D9DED4` | `#394132` | Nonessential row separators only |
| Focus ring | `#415600` | `#C6FF00` | Visible focus with separation from the control |
| Disabled fill / text | `#E2E7DC` / `#555D50` | `#30382A` / `#B9C2B1` | Explicit opaque pairing; explain blocking reason separately |
| Error fill / text | `#FFECEE` / `#972D32` | `#3A1E22` / `#FFC4CA` | Field errors and destructive context |
| Pending fill / text | `#FFF1CC` / `#775000` | `#352B16` / `#FFE0A3` | Under review, payment verification, unresolved work |
| Success fill / text | `#E6F5EB` / `#185D38` | `#173523` / `#A8E5BF` | Server-confirmed successful state |
| Information fill / text | `#E7F0FC` / `#1B4F82` | `#182D43` / `#BEDAFF` | Neutral guidance |

Lime is an emphasis color, not proof of KYC, payment settlement or completion.
Status always has text and, where useful, an icon. For light-mode text links use
ink or the dark focus color with a clear link affordance, never lime on white.
Give light-mode lime controls an ink/outline boundary where needed to identify
the control; use a visibly distinct focus stroke (see the shared-action refinement
below). Test selected and
unselected indicators without relying on fill hue alone.

Calculated solid-color examples: primary ink on lime **15.5864:1**; secondary
light text on white **6.8452:1**; light input boundary against canvas **4.3746:1**.
Lime against white is only **1.1860:1** and is unsuitable as readable text there.
These are arithmetic token checks, not rendered-app contrast verification.
Target at least 4.5:1 for all ordinary app text and 3:1 for meaningful control
boundaries/icons, including actual alpha, parent surface and states. Reference:
[W3C text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
and [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).

Both modes share hierarchy, component sizes and information. Respect the user's
existing system/light/dark preference; do not silently reset it. Keep wallpaper
dynamic color off for this brand direction. Make system bars, dialogs, map
overlays, image placeholders and keyboard-adjacent surfaces part of the review.

Inverse panels carry their own local content roles even in light mode: primary
text `#F5F7F1`, secondary text `#B9C2B1`, meaningful outline `#86947B`, and focus/
links `#C6FF00` on inverse `#11150F`. Do not inherit light-mode secondary ink or
the dark light-mode focus ring into an inverse panel. Controls on lime retain
dark ink and a focus stroke distinguishable from their actual fill.
Status chips and popovers keep their complete paired surface/content roles.

### Typography, in sp

| Purpose | Family | Size / line height | Weight |
| --- | --- | --- | --- |
| Page title / short hero title | Space Grotesk | **28 / 34** | **600** |
| Section heading | Space Grotesk | 20 / 26 | 600 |
| Card title | Space Grotesk | 18 / 24 | 600 |
| Reading body / essential instructions | Inter | **16 / 24** | **400** |
| Primary button / emphasized field label | Inter | 16 / 24 | 600 |
| Secondary button / compact label | Inter | 14 / 20 | 600 |
| Supporting text | Inter | 14 / 20 | 400 or 500 |
| Noncritical timestamp / caption | Inter | 12 / 18 | 400 or 500 |
| Financial number / summary value | Inter, tabular figures where supported | 20 / 28 or 28 / 34 | 600 |

Use sentence case. Avoid a proliferation of display sizes, thin essential text,
forced line breaks, uppercase paragraphs or negative tracking on Indian scripts.
The specimen “Every detail in good hands” is design copy, not a required title on
every screen. Money, consent, verification instructions and recovery actions use
14–16sp or larger rather than the smallest caption role.

Bundle actual Space Grotesk 600 and Inter 400/500/600 weights in `res/font`; retain
source revisions, hashes and their licence notices. No network font loading in
the app. Compose supports bundled fonts and explicit weight mapping:
[Android font guidance](https://developer.android.com/develop/ui/compose/text/fonts).
The upstream font notices are [Space Grotesk](https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/OFL.txt)
and [Inter](https://raw.githubusercontent.com/google/fonts/main/ofl/inter/OFL.txt).
Use a tested Noto Sans Devanagari/Telugu strategy for supported scripts, with
verified assets/licences before bundling. Check mixed English/Indian-script names,
the rupee symbol, digits and 400/500/600 rendering. Do not assume Latin fonts or
multiple same-weight `Font` entries automatically provide correct glyph fallback.

### Geometry and movement, in dp

| Element | Specification |
| --- | --- |
| Main action | Pill/50% corners; **52dp minimum height**, grows with text |
| Other actions and icon buttons | **48dp minimum effective target**, nonoverlapping |
| Standard card | **24dp** corners; 16–20dp internal padding |
| Hero / main summary card | **28dp** corners; 20–24dp padding |
| Input | **16dp** corners; minimum 56dp field area; label/error outside fixed text height |
| Dialog / sheet | **28dp** corners, sheet top corners only; scrollable content and reachable actions |
| Small status badge | 8dp corners; plain display badges are not fake buttons |
| Selectable chip / nav indicator | Pill shape; selected semantics and label retained |
| Spacing | 4 / 8 / 12 / 16 / 20 / 24 / 32 scale; 20dp page inset, 16dp on narrow screens |
| Shadow | Restrained 0–2dp for ordinary cards; separation primarily by surfaces |
| Animation | 120ms control feedback; 180–220ms layout/state transitions; respect system motion settings |

Minimum targets follow [Android Compose accessibility defaults](https://developer.android.com/develop/ui/compose/accessibility/api-defaults).
Implementation refinement for large text: shared actions use a **26dp radius
cap**, forming a capsule at 52dp. When a translated or enlarged label makes an
action taller, its height grows while its corner radius stays 26dp. This avoids
cutting the first/last text lines with oversized circular corners. This is an
accessibility refinement of the reference silhouette, not a fixed-height button.
For shared lime actions, focus uses a **3dp ink stroke inside the lime fill**,
replacing the normal 1dp outline. This refines the originally proposed external
ring/gap: the visible change is measured against lime, including on an inverse
parent where an external ink ring could disappear. A real keyboard focus request
and before/after rendered pixels must verify the transition.
No fixed-height text containers, horizontally scrolling primary forms, rotating
decorative bots or dashboard animations inside transactional app screens.
Loading indicators run only while actual work is pending. Disable shimmer under
reduced motion; keep state changes understandable without animation.

## 2. Screen scope and source map

The static inventory at the baseline contains **98 page/screen declarations**:
**91** associated with registered navigation destinations, **5** root/activity
surfaces, and **2** retained legacy/unmounted screens. There are **92 navigation
registrations**, including a legacy redirect; counts are not interchangeable.
`SecureScreen` is a protection effect, excluded from the page count. Shared Home,
job detail and DSR have role/state variants recorded in the plans. Dialogs and
sheets are additional surfaces, not hidden in a misleading page count.

The page map reconciles declarations with graph registrations and deliberately
distinguishes source association from verified runtime reachability. It is not a
whole-code audit. Feature planners inspected UI/action source; no real accounts,
providers or devices were exercised for this plan.

- [Complete source inventory](ui-renewal/source-map.md): each declaration, source
  line, graph binding, implementation batch and baseline file hash.
- [Account, auth and shared page designs](ui-renewal/account-pages.md).
- [Hospital, discovery and AMC page designs](ui-renewal/hospital-pages.md).
- [Engineer, evidence and earnings page designs](ui-renewal/engineer-pages.md).
- [Founder/admin page designs](ui-renewal/founder-pages.md).

Each page inherits section 4's state/recovery contract. The per-page row supplies
its hierarchy, actual entry/action/exit, unique prerequisites and exceptions.
Implementation must record missing UI states as work to add with tests; a proposed
retry, retained draft or safe payment state is not evidence it exists today.

## 3. Navigation and page families

Keep existing route identifiers and public callbacks during the visual migration.
Hospital tabs remain **Home / Bookings / Messages / Profile**. Engineer tabs remain
**Home / Jobs / Earnings / Profile**; retain Messages as a prominent existing
Home/Jobs action. Keep labels visible, selected state announced, badges textual,
and deep subflows full-screen where the existing route contract requires it.
Do not add an always-visible admin tab or turn root role confirmation into a
cosmetic local preference. Back/pop and restored-tab behavior require tests.

Startup also has a design row: native splash keeps the original mark and a paired
solid background, with no delayed promotional screen. `DevModeBlockingScreen`
(`core/security/DevModeBlockingScreen.kt:54`, called from `MainActivity.kt:83`)
uses a scrollable reason/instructions layout, readable status and a flexible
Open settings action. Test missing settings handler, small/large-text layouts and
return-to-app behavior against the current integrity verdict; do not weaken or
bypass the security block while theming it.

| Family | Layout pattern |
| --- | --- |
| Entry and authentication | Short heading, logo, persistent form labels, one lime action, visible recovery and secondary provider/account actions |
| Home | Identity/workspace heading, one next-action panel, compact shortcuts, actionable work list; no invented counts or charts |
| Lists and queues | Title and real count/filter, dense readable rows, key status and next action; useful empty and partial-error states |
| Detail and work order | Object identity, lifecycle/status, current task, grouped evidence/terms/history; one state-specific primary action |
| Forms | Meaningful sections, persistent labels, local field errors, IME-safe actions; long forms scroll without shrinking text |
| Money | Amount plus explicit status, itemized authoritative values, pending/retry/receipt context; lime never implies settled funds |
| Maps and calendars | Accessible list alternative, labeled controls, provider/permission failures; no decorative live-tracking claims |
| Account/settings | Identity then grouped personal, work, security, preferences and support rows; sensitive actions visually separated |
| Admin | Compact prioritized queues, visible entity context, review-first actions, readable evidence and audit history |

## 4. Contract for every page and overlay

Before editing a page, bind its plan row to the current source hash, owner/session
requirements, entry arguments, primary/secondary actions, eligibility and Back/
dismiss/restart behavior. Use these common states where applicable:

| State | Required presentation and behavior |
| --- | --- |
| Resolving first load | Stable geometry with labeled progress; no previous account's data or fabricated zero counts |
| Ready | Real content, long names/IDs/amounts wrap appropriately; one clear next action |
| Empty | Task-specific explanation and an existing useful action; never use empty to conceal an error |
| Refreshing with data | Retain same-account valid data, show refresh progress/failure, and identify stale content when freshness matters |
| Failed / offline | Plain cause when known, explicit Retry or supported recovery; preserve entered same-owner values to their real durability level |
| Sending / saving / uploading | Name the pending operation; prevent duplicate submission; cancellation/dismiss rules reflect the actual operation |
| Partially saved / queued | State exactly which work is durable or queued and which failed; no general “saved” promise |
| Payment pending / uncertain | Keep reconciliation visible; no repeat charge or success animation until authoritative confirmation |
| Denied / verification pending | Show the actual prerequisite and safe next step; unavailable status stays distinct from rejected status |
| Success | Show confirmed result and meaningful next destination; route only after the existing authority validates the result |
| Expired, replaced account or lost access | Retire private content and callbacks; clear/retain only according to captured-account ownership, not a live replacement user |

Validation errors live with their fields and are announced appropriately. Focus
moves predictably after errors, modal entry and dismissal. Photo/document controls
need meaningful labels and upload/retry/remove states. Empty states, toasts,
snackbars, context menus, selectors, confirmation dialogs and progress overlays
all use the same semantic tokens and typography.

Back behavior is part of the design. Close the current modal before leaving its
page. For unsaved edits, distinguish cancel/discard from a committed mutation;
never claim process-restart persistence without a storage/state test. Do not
add persistence of passwords, OTPs, bank details or identity documents merely to
make a form look recoverable. Account-sensitive pending work waits for A4/A12.

System-owned flows remain system-owned: Google Credential Manager, camera/photo
picker, location/notification permissions, browser/legal pages, sharing, maps,
payment SDK and document viewers. Theme our launch/return/error surfaces and test
cancel/denial/missing-handler/restart; do not counterfeit a system permission or
provider screen. No provider activation or business-policy change is a UI task.

## 5. Architecture and migration safeguards

`Color.kt` contains Seva and older palettes; `Theme.kt` still assigns older colors
to Material 3. `Type.kt` and `Typography.kt` each define separate default-font
styles. `Shape.kt` gives every Material slot 5dp, while `EsTokens.kt` defines a
different radius scale. Fix these shared sources before hand-tuning pages.

1. Introduce one canonical role-based color system with complete light/dark
   Material slots and additional paired status/inverse roles. Both shared and
   Material components consume those roles.
2. Define one typography role table feeding both `EsType` and Material typography;
   resolve bundled fonts and supported scripts deliberately. Keep compatibility
   adapters until callers migrate.
3. Align Material shapes, `EsRadius`, spacing, elevations and motion tokens.
   Migrate `EsBtn`, primary/tonal buttons, fields, chips, nav, cards, banners,
   sheets, dialogs and loading/empty/error components.
4. Migrate each page away from concrete palette imports/raw sizes. Do not replace
   every old green with lime: that would break white text, status meaning and the
   unchanged logo. Audit translucent fills and disabled states in context.
5. Keep existing Compose/coroutine/MockK/Robolectric tooling. Use existing UI and
   capture infrastructure; `compareRoborazziDebug` is an old proposal, not an
   observed configured task. No new dependency is implied by this plan.
6. Keep UI state and business effects separate. Extract small presentational
   sections from large screens only where needed; retain owner/cancellation and
   callback contracts with regression coverage.

No auth-repository, database/RPC, payment-rule, KYC-eligibility or security-guard
rewrite is bundled into a color migration. Confirmed behavior bugs have their own
test-first slices and integration points. Known current dependencies include:

- **A3:** external-route admission and notification/deep-link replay. Notification
  destinations and privileged routes cannot pass end-to-end acceptance first.
- **A4/A12:** sign-out cleanup, token revocation and account-owned mutations. Profile,
  saved work, account switching and sensitive forms depend on these fixes.
- **Earnings destination:** `MainNavGraph.kt:811` routes the payout-method action
  into generic bank settings; reconcile it with the actual payout editor.
- **Engineer status:** the Jobs hub's own load failure must not present itself as
  confirmed non-engineer/KYC ineligibility. This is separate from completed A10.
- **Payment/evidence truth:** review the source findings in the engineer/hospital
  appendices before redesigning completion, payout-readiness or evidence states.
- Preserve A1, Room v5, A2 and A10 successful paths and regressions; don't repeat
  completed work or infer all security work is closed from their prior scores.
- Triage the previously observed HIGH default-branch Dependabot alert 17 before
  main/release integration. Its exploitability/status has not been audited here.

## 6. Implementation sequence

UI-00 is reviewed as the planning baseline. **UI-01 is locally accepted** together
with **UI-02's shared-action, text-field and dropdown slices**; UI-02 as a whole
remains in progress. OTP and the other shared families still require migration.
UI-03 through UI-11 remain planned for this theme. Finish and review one bounded
batch before expanding. Separate security fixes from visual commits.

| Batch | Work | Completion evidence |
| --- | --- | --- |
| UI-00 | This selected-theme specification, reconciled page map and state contracts | Source-bound plan review; owner's theme choice recorded; no runtime score |
| UI-01 | Bundled fonts, canonical colors/type/shapes, complete light/dark theme | Focused font/token/contrast tests; component gallery; legacy adapter review |
| UI-02 | Buttons, fields, cards, status, nav, dialogs, sheets, common states | Real enabled/disabled/focus/selected/error renders; small screen, large text, EN/HI/TE |
| UI-03 | Welcome, sign-in/up, recovery, role gate, setup, KYC and tour | Provider/session/role regressions, IME/Back/partial-save tests; native auth acceptance separately |
| UI-04 | Hospital home, bookings, request form/confirmation, directory/public profile | Request/restore/cancel/acceptance paths and phone/eligibility gates; honest offline draft behavior |
| UI-05 | Shared job detail, bid comparison, terms, payment, evidence, DSR and disputes | Both-role state fixtures; authoritative money states, account isolation and retained evidence; A3/A4 integration |
| UI-06 | Engineer home/jobs hub/feed, bids, active work, work/location/profile tools | Verified/pending/rejected/unavailable separation; safe queue/permission/retry paths |
| UI-07 | Earnings, payout editor, active escrows, projection/profitability/tier previews | Correct destinations; partial/failed/readiness/payment states; provider acceptance remains separate |
| UI-08 | Profile/forms, preferences, account security, chat, notifications, About/support | All modals/legacy dispositions; privacy, safe role/sign-out/edit ownership; A3/A4/A12 |
| UI-09 | AMC contracts, wizard/detail, calendar/fleet/history/portal, AMC visits/perks | Renewal/source args, visit/state rules, request-for-review semantics, partial-read recovery |
| UI-10 | Every founder/admin queue/detail/editor | Privileged API denial, sensitive-document protection, safe confirmations, audited payment effects |
| UI-11 | Cross-app polish and acceptance | Complete page/state ledger, both-role native journeys, locales/accessibility, signed-release checks |

UI-03 is subdivided into auth entry, root/setup and KYC batches; UI-05 into job
overview/bids, financial decisions and evidence/DSR. UI-08 and UI-10 are split into
small file-owning batches. This prevents a giant unreviewable “all screens” commit.
Shared component changes must first render representative existing users of those
components, since their impact is wider than the files edited.

Use separate implementing and reviewing agents with bounded file ownership.
One coordinator owns `MainNavGraph`, shared theme/component changes and integration.
Do not allow parallel agents to rewrite a shared file or compete for Gradle.
On this laptop recheck `outputs/equipseva-build-slot.md` before reserving a build.

## 7. Verification and score rules

For each implementation batch, freeze negative and valid-path cases against the
starting source before implementation, and capture relevant failing behavior
first. Bind the final results to the final source hashes. Run targeted coroutine/Compose tests,
then the required full `:app:testDebugUnitTest`, `:app:lintDebug`,
`:app:assembleDebug` and applicable `:app:assembleRelease` checks before acceptance
or an application-change push. Respect the existing release precheck and record
environment failures; an unsigned release assembly is not a shipped release.

Screenshots/semantics must cover light and dark, EN/HI/TE, normal and 2.0x text,
small width (320/360dp), short landscape, loading/empty/error/ready and relevant
pending/denied/success states. Test API 26 font compatibility and representative
current supported Android configurations, including keyboard, insets and Back.
Use synthetic owner-separated fixtures; keep private real data out of evidence.
Measure actual colors/alpha and text/control bounds. Do not loosen screenshot
tolerances or remove failing cases to obtain a pass.

Native TalkBack, switch/keyboard traversal, IME, permission/provider return and
real-device rendering remain mandatory for affected final journeys. Representative
hospital and engineer usability tasks are human validation, separate from agent
reviews. Collect that evidence when users/devices are available; don't invent it.

Use the existing renewal rubric: task correctness 25, security/privacy 25,
resilience/data/money 20, usability/accessibility/localization 15, consistency 10,
performance/operations 5. Independent critic **and** QA must each score at least
**9.5/10**, and each applicable critical dimension must reach that threshold.
Missing mandatory evidence is **not scored / not accepted**. High security issues,
blocked journeys, evidence loss, wrong money states or crashes override a score.
Prior Welcome/A2/A10 ratings describe their old scope and do not approve this theme.

Maintain implementation, review, integration and native/release-verification
columns separately in the inventory. Do not calculate whole-app completion from
page count, changed colors, agent activity, test totals or planning coverage.

## 8. Save, integration and immediate next step

Commit planning documents separately. Fetch again before each milestone commit
and preserve other worktrees. Application batches land on the integration branch
with their evidence; main promotion remains subject to the open security and
applicable integration gates. No force push, silent gate bypass or unsupported
production deployment is part of the redesign.

Update the development dashboard only for a completed major milestone with an
explicit scope and verified facts. Planning alone does not advance an app
completion percentage, agent-hours counter or release score.

**Next implementation step:** UI-02 OTP inputs, cards, status, navigation,
dialogs/sheets and common feedback, in bounded caller-aware batches. Then UI-03's
auth-entry pages. Recheck source/branch/build-slot state first.
Keep per-page implementations staged in the sequence above, with before/after
evidence. The original UI-00 planning pass changed documentation only. Current
UI-01/action/input results are in the linked ledgers; they make no app release claim.
