# Independent QA matrix (review only; nothing executed by this reviewer)

Base `1e770076358e74f6f40a99a4907f831da59e791c`. This matrix converts the A3, A4/A12, A8 and
UX reports into reproducible acceptance cases. Evidence classes: **U** JVM unit test,
**C** Robolectric Compose test, **API** server test (PGlite/Node suite or direct REST call
against a test project), **D** device or emulator run, **H** human check (translation
quality, TalkBack usability, user task). "Status" says who executed what at this base; every
case not marked executed is **unassessed**, not failing and not passing.

## A. Executed evidence that exists at this base (recorded by the coordinator, not re-run here)

| Record | Evidence | Where |
| --- | --- | --- |
| A2 focused bar | 138 tests / 10 suites, 0 failures (run04), including `RootSessionHostTest` 23, `SessionViewModelIdentityTest` 56, `RoleSelectViewModelTest` 23, UI suites 9 | `docs/evidence/auth-a2/verification.json`, `auth-a2-qa-review.md` |
| Full debug unit suite | 3,030 tests / 351 suites, 0 failures; lint 0 errors; debug + unsigned release assembly | same |
| A1 | 47 focused, 2,951 full, CI runs 34498001037 / 34498001057 green on `d140c19b` | `docs/HANDOFF_2026-09-10_END_OF_DAY.md` |
| Helper integration tests | INT-01..INT-04 green locally and in CI on `claudedev-help`, merged at `1054e473` | `docs/HANDOFF_CLAUDEDEV_HELP.md` |
| This review | **none** — static reading only; no Gradle, no device, no server call | this folder |

Known open blocker recorded by the coordinator: RoleSelect dark-theme contrast 2.378:1
(hard blocker for A2 acceptance; not waived here).

## B. Acceptance cases

### B1 · A3 deep links

| ID | Case | Stimulus | Expected (target) | Class | Status | Prerequisite / blocked by |
| --- | --- | --- | --- | --- | --- | --- |
| QA-A3-01 | External route injection denied | explicit intent with `EXTRA_ROUTE = founder/dashboard` (T-A3-01) | dropped; no navigation | U (Robolectric) | unassessed | policy in `DeepLinkRouter` |
| QA-A3-02 | Legitimate push taps preserved | 34 kinds through the parser → intent → dispatch → host | route delivered when owner matches | U | unassessed (parser alone is executed: 42 existing tests) | T-A3-06 builder |
| QA-A3-03 | App Link whitelist unchanged | `DeepLinkRouterTest` 11 cases | still green | U | **executed** (part of the 3,030) | — |
| QA-A3-04 | Signed-out delivery dropped | dispatch while `SignedOut`, then `SignedIn(B)` | no event for B | U | unassessed | owner gate in `DeepLinkHost` |
| QA-A3-05 | A → SignedOut → A replay dropped | event under generation 1, replay under generation 2 | dropped | U | unassessed | generation stamp |
| QA-A3-06 | Cold-start tap buffered for the same owner | two events before the collector | both delivered in order | U | unassessed | — |
| QA-A3-07 | Process restore does not re-dispatch | `ActivityScenario.recreate()` | one router event total | C/D | unassessed | `savedInstanceState` guard |
| QA-A3-08 | Tray cancelled on sign-out | wipe → `cancelAll()` | called before network steps | U | unassessed | A12 ordering |
| QA-A3-09 | Chat notify-id collapse | `chat_message_new` with a conversation id | same id per conversation | U | unassessed (today's test pins the wrong literal) | — |
| QA-A3-10 | Server data whitelist | inserting functions per kind | `data` keys ⊆ whitelist; recipient is a party | API | unassessed | fixtures per kind |
| QA-A3-11 | Device: third-party intent | adb `am start` with the extra on a debug build | founder UI does not mount; snackbar or silent drop | D | unassessed | debug build, test account |

### B2 · A4/A12 mutation ownership and A8

| ID | Case | Stimulus | Expected (target) | Class | Status | Prerequisite |
| --- | --- | --- | --- | --- | --- | --- |
| QA-A4-01 | Stalled cleanup cannot wipe B | T-A4-01a | B's outbox row and escrow marker retained | U | unassessed | barrier fake for `revoke()` |
| QA-A4-02 | Same-uid re-login protected | T-A4-01b | new A's rows retained | U | unassessed | owner token, not uid |
| QA-A4-03 | Cancellation stops cleanup | T-A4-01c | no further steps | U | unassessed | helper that rethrows cancellation |
| QA-A4-04 | Revoke targets the captured user | T-A4-02 | DELETE for A or no-op | U | unassessed | mockkStatic AuthKt |
| QA-A4-05 | Sign-out failure keeps retained work | T-A4-03 | fences applied, no destructive wipe, honest state | U | unassessed | single owned sign-out path |
| QA-A4-06 | Signup late `addRole` | T-A4-04 | no mirror write for B; cancellation not a crash report | U | unassessed | A7 design |
| QA-A4-07 | Role editor late success | T-A4-05 | no mirror write; root refresh only | U | unassessed | — |
| QA-A4-08 | HomeHub data role = validated role | T-A4-06 | mirror ignored | U | unassessed | VM input change |
| QA-A4-09 | Viewer role never from mirror | T-A4-07 | not engineer without server signal | U (pure) | unassessed | — |
| QA-A4-10 | Legacy role key fallback | T-A4-09 | no stale legacy value observed | C | unassessed | seeded DataStore |
| QA-A4-11 | Cleanup coverage | T-A4-10 | `hospitalPostedFirstJob` reset | U | unassessed | — |
| QA-A8-01 | Self select failure is `Unavailable` | MockEngine 401/403/decode error | retry gate, no chooser, no wipe | U | unassessed | typed outcome |
| QA-A8-02 | Row absent is `NotFound` | authenticated 200 empty | deleted-account path only then | U | unassessed | — |
| QA-A8-03 | Payout readiness unknown | payout RPC 500 | `Unknown`, onboarding not admitted to MAIN | U | unassessed | product decision §6.6 of the UX plan |
| QA-A1-REG | A1/A2 regression | `SessionViewModelIdentityTest` 56, `RootSessionHostTest` 23 | green | U/C | **executed by coordinator** | — |

### B3 · Login, role, setup, account switching (UX)

| ID | Case | Stimulus | Expected | Class | Status | Prerequisite |
| --- | --- | --- | --- | --- | --- | --- |
| QA-L-01 | RoleSelect dark contrast | dark scheme capture | CTA text ≥ 4.5:1 | C | **unassessed; recorded FAIL at this base (2.378:1)** | S0 fix |
| QA-L-02 | Setup screens have an exit | hospital/engineer base setup mounted | sign-out reachable, owner-guarded | C | unassessed | S1 |
| QA-L-03 | No inert controls | phone-onboarding legacy screen | no focusable no-op back arrow | C | unassessed | S1 |
| QA-L-04 | Submitting state visible | sign-in/sign-up/forgot submit | progress indicator, single submit | C | unassessed | S2 |
| QA-L-05 | Error banner retry | network failure then retry | second call issued once | U/C | unassessed | S2 |
| QA-L-06 | Email confirmation state | `NeedsEmailConfirmation` | persistent state with the email and a resend action | C | unassessed | S2, decision §6.5 |
| QA-L-07 | Large text, three locales | 320 dp / fontScale 2.0 EN/HI/TE on L1–L11 | no clipped or ellipsised primary text | C | **executed for RoleSelect only** (9 captures, light theme) | S3 |
| QA-L-08 | Keyboard does not hide the CTA | IME open on the four setup forms | CTA reachable | C/D | unassessed | S3 |
| QA-L-09 | Translations present | value diff for auth/onboarding keys | zero English values in hi/te | U (script) + H | unassessed; 47 English values today | S4 |
| QA-L-10 | Radio semantics | SignUp tiles, Profile role editor | grouped radio buttons, selected state announced | C + D | unassessed | S2/S4 |
| QA-L-11 | Jobs tab reflects KYC decision | KYC submitted → return | status refreshed without restart | U/D | unassessed | S6, A10 |
| QA-L-12 | TalkBack traversal and announcements | L1–L14 on a device | logical order, errors announced, no traps | D + H | unassessed | device session |
| QA-L-13 | Real provider sign-in | email and Google against the test project | success, cancel, wrong password, unconfirmed email | D | unassessed | test accounts, Google client id |

### B4 · Hospital and engineer journeys (UX)

| ID | Case | Stimulus | Expected | Class | Status | Prerequisite |
| --- | --- | --- | --- | --- | --- | --- |
| QA-H-01 | Stranded escrow payment is visible | pending marker present after restart | Home and job detail show the in-flight payment | C | unassessed | S5 |
| QA-H-02 | Hospital money writes retry | accept/release/dispute failure | retry affordance re-issues once | U/C | unassessed | S5 |
| QA-H-03 | Bookings list localised | HI/TE capture | no English literals | C + H | unassessed | S5 |
| QA-H-04 | Evidence photos announced | job detail with photos | descriptive labels | C + D | unassessed | S7 |
| QA-H-05 | Draft recovery after process death | request form, kill, relaunch | Keep/Discard bar with the draft | D | **executed at the ViewModel/store level** (INT-01/INT-02 helper tests); device unassessed | — |
| QA-E-01 | Hub error vs not-engineer | verified engineer, fetch error | retry hero, tiles hidden, no "become verified" copy | U/C | unassessed | S6 |
| QA-E-02 | Earnings "Fix method" route | tap CTA | payout-method screen | U (route assertion) | unassessed | S6 |
| QA-E-03 | Queued evidence visible | outbox rows pending/failed | pill with counts; failed items listed in-app | U/C | unassessed | S7 |
| QA-E-04 | Check-in gates | no photo / no GPS / wrong status | CTA disabled with reason | C | unassessed | — |
| QA-E-05 | Untranslated screens | jobs hub, active work HI/TE | no English literals | C + H | unassessed | S4 extension |
| QA-J-01 | End-to-end both roles on device | request → bid → accept → pay (sandbox) → check-in → DSR → release | each state honest, no crash | D | **partially executed earlier** (RPR-00040/41 DSR chain per memory notes, before A1/A2); not re-run at this base | sandbox payment rail decision |
| QA-J-02 | Representative users | observed hospital and engineer tasks | task completion, failures recorded | H | unassessed (M2b) | recruitment |

## C. Disposition (no numeric scores from this review)

| Area | Static review | Executed evidence at this base | Disposition |
| --- | --- | --- | --- |
| A3 deep-link contract | complete for the traced files | parser tests only | **two HIGH defects open (A3-01, A3-02)**; contract and tests proposed; cannot pass until fixed and tested |
| A4/A12 mutation ownership | complete for the assigned files | A1/A2 owner tests green; none for the unowned writers | **two HIGH defects open (A4-01, A4-02)**, five MED; A1/A2 scope itself not re-scored |
| A8 profile fallback | complete | none | recommendation; MED risk (destructive action on ambiguous read) |
| Login/role/setup UX | complete (static) | RoleSelect UI captures, light theme | dark-theme blocker open; exits and in-flight states missing; unassessed for device/TalkBack/translation quality |
| Hospital journey UX | static exploration | helper store tests | unassessed for acceptance; defects listed in the plan |
| Engineer journey UX | static exploration | none beyond unit suites | unassessed; functional defects listed (hub error folding, earnings CTA route) |
| Device, TalkBack, languages, dark, human validation | not performed | none | unassessed |

Critical defects are not averaged into any dimension: A3-01, A3-02, A4-01 and A4-02 each
block a passing security/privacy or data-retention disposition on their own. A2's recorded
conditional scores remain the coordinator's, unchanged by this review.

## D. Prerequisites for the blocked classes

- **D (device)**: a debug build of a fixed head, the `eqs` emulator or a phone, two test
  accounts (hospital, engineer), Google client id for the debug build, the coordinator's Gradle
  slot free (`docs/renewal-snapshots/2026-09-11/equipseva-build-slot.md`).
- **API**: PGlite or a disposable Supabase project with the migration chain; fixtures for the
  34 notification kinds; never the production project.
- **H**: Hindi and Telugu reviewers for value translation; TalkBack user session; M2b
  participants (recorded counts and failures, per the plan).
- **Payment**: a sandbox rail decision (Cashfree/RazorpayX, open per project memory) before
  QA-J-01 can include a real payment.
