# Independent secret-scan QA — 2026-09-19

**Scoped QA score: 9.5/10. No reproducible blocker found in the frozen CI replacement.** This score covers source review, executed offline contracts, and the coordinator-observed hosted results below. It is not whole-app/security/release acceptance.

Reviewed clean commit `49b3cbecd9970a5bbd3a261b28f166bb1f3bc91a` in `work/equipseva-secret-scan-20260919`: `.github/workflows/secret-scan.yml`, `scripts/verify/secret_scan.py`, and `scripts/verify/test_secret_scan.py`. Reviewed the unchanged `.gitleaks.toml`, author handoff, actual test logs, exact-flags redacted scan, prior exhaustive checksum ledger, and positive-control source/result. No source edits, tests/Gradle execution, ignore changes, or commits by this reviewer.

## Executed evidence checked independently

- `secret-scan-final.log`: **26 tests, all passed, 42.306 seconds**. AST extraction finds exactly those same 26 test method names in the frozen test source; no missing or relabeled case. The coordinator's independent rerun, `secret-scan-independent.log`, also ends **26 tests / OK**, 42.624 seconds; this reviewer read that log directly.
- Real-CLI controls cover a removed secret beyond the original first 30 commits, a removed merged-side-branch secret, and a merge-resolution-only addition. Each explicitly checks the old command misses the fixture and the replacement blocks it. A separate clean-merge control shows first-parent *diff formatting* avoids duplicating unchanged old first-parent content while all ancestry remains traversed.
- Positive controls cover clean PR/push, fresh ordinary/new-branch findings, a nonancestor force-push range, and zero-commit ranges that still require a functioning engine. Failure cases cover malformed/missing event metadata, wrong HEAD, missing commit/blob/default ref, shallow history, dirty/untracked/symlink policy, wrong/missing/failing engine, error output despite exit zero, and redaction. Only a consistent branch-deletion event skips the engine.

The fixtures use disposable synthetic repositories and require the real CLI rather than skipping when unavailable. Mocked cases are limited to operational conditions that cannot conveniently be induced through the normal binary; the history/security regressions execute real Git and Gitleaks.

## Hosted results observed by the coordinator

The coordinator inspected the actual GitHub browser logs; this reviewer did not independently reopen those pages:

- [Linux push run 35437875937, job 105883528554](https://github.com/ganeshnaik166/equipseva-android/actions/runs/35437875937/job/105883528554) succeeded. The observed log contains **26 tests passed in 12.631 seconds**, followed by the exact `e4a5e0db903fae465e8ddb2c1348d657d98f032b..49b3cbecd9970a5bbd3a261b28f166bb1f3bc91a` range: **one commit, clean**.
- [PR run 35437909233](https://github.com/ganeshnaik166/equipseva-android/actions/runs/35437909233) also succeeded.

These close the hosted Linux execution gap for the CI-repair commit. They do not establish a clean result for the larger application candidate's post-exception range.

## Source judgment

- The workflow checks out the event head with full history, removes PR write permission, and disables persisted checkout credentials. It verifies the downloaded pinned CLI archive before running it, then executes the contract suite before the actual scan.
- The helper derives a validated SHA range from the event instead of relying on a paginated commit-list API. Its exact patch flags are `--full-history --diff-merges=first-parent --no-ext-diff --no-textconv --no-renames`; it does **not** restrict ancestry traversal with `--first-parent` or suppress merges.
- Git identity/history/object/patch validation precedes scanning. Policy files must be tracked regular files in the clean checkout. Inherited Git/Gitleaks settings are removed; replacement objects and lazy fetching are disabled. Expected version, explicit policy paths, finite timeouts, and strict engine exit/output checks fail closed.
- Git and engine output is captured, never forwarded. Diagnostics are fixed categories; printed range/count data comes from validated metadata. Findings and operational errors both block success. No new rule/path/baseline suppression belongs to this CI commit.

## Exact 70-fingerprint comparison

`gitleaks-final-flags-before.json`, generated with the final flags including `--no-renames`, contains **exactly the same 70 fingerprints** as `gitleaks-triage.recommended-fingerprints.txt`: 64 generic-rule and six Sentry-rule findings. There are no missing, extra, or duplicate fingerprints. Commit, file, line, and rule metadata also match the exhaustive ledger; all reported values are redacted.

Every one is already proven to be a source-file checksum through historical schema and actual source-byte reproduction. The full 208-finding audit remains available; its seven mixed-ending cases now reproduce from pinned Git blobs and recorded newline positions with zero working-source reads. This QA review adds no broad exception and applies no ignore entry.

The extended `check_gitleaks_positive_control.py` and updated `gitleaks-positive-control-result.json` were read directly after the follow-up. The fixture installs the exact 70 proposed fingerprints and unchanged project rules, then exercises both the direct CLI with **all five final patch flags** and the actual `secret_scan.py` helper with a synthetic PR event:

| Control | Clean exit | Fresh synthetic finding exit |
| --- | ---: | ---: |
| Gitleaks CLI with exact final patch flags | 0 | 23 |
| Actual event-history helper | 0 | 1 |

The detected default rule is `github-pat`; the source asserts that the generated fixture value is absent from direct output, helper output, and the redacted report. The result records redaction as true. No provider-issued credential or service request is used. This closes the earlier direct-CLI/reduced-flags precision limit and proves the proposed exceptions retain this fresh default-rule detection through the real helper.

The coordinator reports that the first wrapper attempt failed fixture validation because inherited Windows newline settings normalized the Git index while the helper intentionally sanitized global/system Git settings. The fixture now explicitly sets local `core.autocrlf=false`, matching the owned regression fixtures, so fixture creation and validation agree. This change is visible in the reviewed external helper; no production scanner change was made. The initial fixture failure is not counted as a passing run or hidden production fix.

## Limits and next gate

- The exact-wrapper positive control covers a fresh synthetic `github-pat` finding; it is not proof that every detector/path is covered. The broader 26-case contracts separately cover history, merge, metadata, and operational-failure behavior.
- Hosted Linux push and PR success are recorded above. Fork behavior and the **actual application's final post-exception range** remain separate checks. The frozen source intentionally fails closed when a prior force-push object is unavailable.
- Existing project allow-lists and changes to CI/policy require review; a job cannot protect itself from an authorized change disabling its own enforcement. This patch does not certify all older repository history or claim the app's open S1/S3, screenshots, device, or release gates are closed.

**Disposition:** the scoped CI repair is supported by source review, local real-CLI contracts, the exact-helper positive control, and the coordinator-observed hosted push/PR results. The exact 70 individual exceptions are evidence-backed; apply them only through the coordinator's separate audited change, then require the actual candidate's final complete-range scan before claiming its secret-scan gate green. That candidate scan is still pending at this report update.
