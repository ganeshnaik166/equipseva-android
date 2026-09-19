# EquipSeva — current work and resume point

Updated 19 September 2026. Read this before coding; verify branch/HEAD and remote state rather than assuming this dated snapshot is still latest.

## Where we are

| Record | Exact checkpoint | Meaning |
|---|---|---|
| Main product plan | `24e0199937c09c137e8045aa7664dcd4f746dbb1`, [PR1879](https://github.com/ganeshnaik166/equipseva-android/pull/1879) merged | Governing four-persona plan, 98 existing-page dispositions, 30 proposed surfaces and seven-page PDF; Android and secret-scan push/PR checks passed |
| Last verified app evidence | `faa2d03e8dddddcc39b02b75eb0b1fab36b77947`, branch `codex/quality-integration-20260919`, [draft PR1877](https://github.com/ganeshnaik166/equipseva-android/pull/1877) | Unaccepted broad integration plus unused registration-intent and region-draft preparation |
| Latest pushed app checkpoint | `e6d0233eba06da209a878aefed0c0739f7890408` | Merged approved main plan into app candidate; font/PDF attributes and historical UX notices both preserved; app source unchanged |
| Active implementation slice | **P1a — AMC cleanup deletion ownership** | Design/test work starting; no implementation or green result claimed yet |

Current app checkout on this laptop: `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-quality-integration-20260919`. The old coordinator (`equipseva-auth-integration-20260911`) and helper worktrees are preserved. Do not use a guessed checkout or silently transfer their changes.

## Product direction

Three public purposes: biomedical engineer, hospital administrator, engineering team/organisation. Platform owner is private and separately provisioned. Paid team administrators have authority within their own organisation; subscription is not a global role grant. Independent engineers retain their personal workspace. Use India State/UT and district, with no-map target workflows; existing GPS/server contracts still require a tested migration. Preserve lime/ink/soft-white, Space Grotesk/Inter and EN/HI/TE. Demo is local synthetic data; digital team subscription and physical service payments are separate. [PRODUCT_PLAN.md](../PRODUCT_PLAN.md) governs details.

## Verified evidence and open gates

- Latest app full run: **3,699 tests, 3 failures, 0 errors, 0 skipped**. All three are preserved `SignOutCleanupLocalBoundaryRegressionTest` assertions. App-wide acceptance is blocked.
- New intent/region preparation: 24-test stub RED (14 assertion failures); unchanged tests GREEN 45/0 with compatibility controls. Critic 9.5, QA 9.6 for these four files only; types are not wired into live UI/permissions.
- Lint, design ratchet, debug assembly and unsigned R8 assembly passed. Release retry corrected the installed Git Bash process PATH. Strict signing/certificate/Sentry/device/provider acceptance is still open.
- Earlier visual record: 116 changed comparisons; only two individually inspected. Do not replace goldens or lower thresholds to turn this green.
- Remaining gates include S1 local cleanup/token capture, S3 logout recovery, M1 payout ordering, M3 provider retry classification, bound integrity enforcement, dependency disposition and full device/provider/human/release validation.
- Planning critic 9.5 and QA 9.6 apply only to the plan. No passing app-wide or security-certification score is claimed.

## Next concrete implementation

Read the [latest app handoff](https://github.com/ganeshnaik166/equipseva-android/blob/faa2d03e8dddddcc39b02b75eb0b1fab36b77947/docs/HANDOFF_WORKSPACE_FOUNDATION_2026-09-19.md) and [existing S1 boundary plan](https://github.com/ganeshnaik166/equipseva-android/blob/faa2d03e8dddddcc39b02b75eb0b1fab36b77947/docs/helper-reviews/codex-20260919/signout-ownership-plan.md).

P1a captures an immutable departing login identity before any cleanup suspension and validates it **inside the real AMC DataStore transform** before removing marker/proof keys together. Write real admission-barrier, reverse-serialization, same-ID reuse, A→B→A, same-account relogin, cancellation, unknown-identity and ordinary-cleanup tests first. Preserve existing safety assertions while adapting fixtures to a reviewed API change.

This bounded slice must not be presented as S1 completion: Room, other stores, photo producers/readers, preferences, token capture, realtime teardown and final SDK logout remain separate ownership boundaries. Do not touch billing, production SQL or unrelated UI while fixing this slice.

## Continuity rule

Update this file, the [milestone log](MILESTONE_LOG.md), affected [delivery ledger](product-plan/DELIVERY_LEDGER.md) row, detailed handoff and supported model memory after every milestone/checkpoint. Future entries must use observed results and exact revisions. Never copy private memory or secret logs into Git. Website development remains paused.
