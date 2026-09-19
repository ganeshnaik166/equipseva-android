# Secret-scan coverage investigation — 2026-09-19

The first app-integration checkpoint is `4eff9984941b63683263b6ed1ade11350ef4660a`, draft [PR 1877](https://github.com/ganeshnaik166/equipseva-android/pull/1877), based on main `e4a5e0db903fae465e8ddb2c1348d657d98f032b`. This investigation supersedes any implication that a green result from the old wrapper proves the whole candidate's secret-scan gate passed.

## Observed GitHub results

- Android PR run 35436516421 failed with **3,675 tests, 3 failures**, the same three enabled `SignOutCleanupLocalBoundaryRegressionTest` cases as the local full run. This is independently observed Linux execution, not inferred from the local result.
- Roborazzi run 35436516410 failed in `Verify screenshots against goldens`: **116 tests, 116 failures**. The log names generated preview comparison failures. Visual differences and baseline compatibility need review; they are not automatically accepted as intended changes. No golden was replaced to clear this result.
- Backend regressions passed for both push 35436441128 and PR 35436516393. This does not close the additional payout/retry-contract findings, which lack regression fixes yet.
- Push secret scan 35436441068 failed with one finding at `push-navigation-independent-review.md:51` in commit `5aaa78f0`.
- PR secret scan 35436516414 reported success, but did **not scan recent commits**. Its actual command selected `c71c2f3506fa5ec0c6e16b67bc22a68a5d9ab9ea^..8a52417a73e99704706d64e976c9bd9286eca75b` despite the PR containing 97 commits and ending at `4eff9984`. Its log reports ten nonempty commits scanned.

## Confirmed wrapper defect

Pinned [gitleaks-action source](https://github.com/gitleaks/gitleaks-action/blob/e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e/src/gitleaks.js) requests the PR commit list once without pagination, then selects the first and last returned SHAs. The default first page is not the complete PR. Its scan also uses both `--no-merges` and traversal `--first-parent`, which omit relevant merged histories and merge-created changes. The v3 pin prevents a moving tag from changing execution; it does not repair these coverage defects.

The replacement is committed separately as `49b3cbecd9970a5bbd3a261b28f166bb1f3bc91a`, [PR 1878](https://github.com/ganeshnaik166/equipseva-android/pull/1878), from main. It uses the same Gitleaks CLI 8.24.3 with a verified release archive, read-only repository permissions, explicit event SHAs and complete Git traversal. Its 26 real-CLI contracts passed in two local runs and hosted Linux execution. The tests reproduce all three old misses and prove missing history/engine errors block acceptance. Independent critic and separate QA: **9.5/10 each**, scoped to this CI slice.

Hosted push run [35437875937](https://github.com/ganeshnaik166/equipseva-android/actions/runs/35437875937) passed. Its actual log records **26 tests in 12.631 seconds, OK**, then `e4a5e0db903fae465e8ddb2c1348d657d98f032b..49b3cbecd9970a5bbd3a261b28f166bb1f3bc91a` (one commit), clean. PR run [35437909233](https://github.com/ganeshnaik166/equipseva-android/actions/runs/35437909233) passed too. These runs validate the isolated CI commit, not this broader application history.

## Findings must be classified individually

The single push finding is a source checksum, not an access credential. The documented value matches the SHA-256 of the reviewed `DeviceTokenRegistrar.kt` byte-for-byte. The current report is reformatted to label the checksum first, avoiding a misleading token-like key/value pair. That does not erase the historical finding.

A complete local scan over main-to-candidate history with `--full-history --diff-merges=separate` produced **208** findings. Comparing every merge against both parents repeats unchanged report contents and assigns new fingerprints. A comparison using `--full-history --diff-merges=first-parent` produced **70** findings: 23 in each of the three historical `docs/evidence/*/verification.json` files and one in the new review. This option controls merge **patch format**, not traversal: there is no `--first-parent` traversal flag. Its adequacy still requires the real CLI merge fixtures and independent review.

An independent reviewer proved **all 208 exact findings** are source checksums by reading their historical schemas and reproducing values from the named Git source blobs. Of those, 201 use CRLF reconstruction; seven use recorded mixed-newline positions, which now replay without any working-source reads. The final exact flags, including `--no-renames`, still yield precisely the same 70 fingerprints. All omitted 138 fingerprints are duplicate presentations of the same document blob, line and rule.

The coordinator installed only those 70 exact historical fingerprints in `.gitleaksignore`. No path/rule/value pattern, baseline or whole-commit exception was introduced. A synthetic positive control using the unchanged project rules and this list passed clean content and detected a new default-rule GitHub-token-shaped value with full redaction. Both the direct CLI with final flags (0/23) and the actual helper (0/1) behaved correctly. The first extended fixture had a Windows inherited-line-ending mismatch; making its local Git configuration explicit fixed the fixture without changing scanner code. This does not establish all-detector coverage or absence of secrets throughout old repository history.

See [the reproducible sanitized ledger](secret-scan-evidence/README.md), which retains every one of the 208 proofs, the final 70 metadata records and pinned newline positions. Publishing retains no matched values or raw source dumps. The final committed candidate scan is a separate gate and is recorded in the root handoff.

Local evidence is under `outputs/quality-review-20260919/`: redacted `gitleaks-full-range-before.*`, `gitleaks-all-parents-first-diff.*`, and the reviewer triage ledger. Only sanitized metadata may be copied into version control.
