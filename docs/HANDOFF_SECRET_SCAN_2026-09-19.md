# Complete secret-scan history — 2026-09-19

Isolated CI repair on `codex/secret-scan-complete-history-20260919`, based on main `e4a5e0db903fae465e8ddb2c1348d657d98f032b`. No Android, backend, signing, security-rule or exception-list changes belong to this slice.

## Reproduced defect and replacement

The old pinned action requested the PR commit list once without pagination and scanned only that page. PR 1877 had 97 commits, but run 35436516414 scanned through `8a52417a` instead of its actual head `4eff9984`. Its `--first-parent --no-merges` flags also skipped side-branch history and merge-created additions. A green badge was therefore insufficient evidence.

The replacement uses the existing Gitleaks CLI **8.24.3**, downloaded from its official release and checked against a pinned SHA-256. It uses validated event base/head SHAs and local full Git history; no commit-list API or write token is needed. Checkout credentials are not persisted.

Exact patch flags: `--full-history --diff-merges=first-parent --no-ext-diff --no-textconv --no-renames`. Merge diff formatting is relative to the first parent, but **all ancestry is traversed**. This detects removed side-branch secrets and additions made only in a merge resolution while avoiding redundant comparisons of unchanged first-parent content against another parent.

Before scanning, the helper checks event shape, checkout identity, nonshallow history, commit/object availability, clean tracked files, and tracked regular policy files. Git patch generation is preflighted with the same options. Engine output is captured and redacted; logs contain only range/count and fixed diagnostics. Malformed events, missing history, wrong engine version and engine errors block acceptance. Only an explicitly valid branch deletion skips the engine. A new feature branch excludes existing default-branch history; default-branch creation without a prior baseline blocks. Force-push history must be available or validation fails.

## Executed evidence

Command: `GITLEAKS_TEST_BINARY=<verified-8.24.3-binary> python -m unittest discover -s scripts/verify -p test_secret_scan.py -v`.

- Test-first checkpoint: intentionally unimplemented helper produced 50 error/subtest entries across 21 methods. This is fixture red evidence, not 50 production defects.
- Frozen implementation: **26 tests, 0 failures/errors/skips**, 42.306 seconds, real Windows Gitleaks 8.24.3.
- Real old-versus-new controls: a removed secret after commit 30, removed side-branch secret, and merge-resolution-only secret all escape the old command and block the replacement.
- Further controls cover clean PR/push, ordinary/new/force-push findings, empty ranges, deletion metadata, missing commit/blob/default ref, shallow checkout, checkout mismatch, dirty/untracked/symlink policy, invalid event/engine/version, and redacted output.
- Independent critic: **9.5/10 for this CI slice**, no reproducible blocker in the frozen implementation. Linux Actions and the final application-history scan remain separate gates.

Local logs are in the parent workspace `outputs/quality-review-20260919/secret-scan-{red,final,independent}.log`. No Gradle build is needed for this Python/workflow slice; Android source is unchanged from main. The workflow itself executes the real-CLI contracts before scanning its event.

## Boundaries

This change does not claim the whole repository history is secret-free. It scans newly reachable event history relative to the stated base. Policy/workflow changes still require review; the CI job cannot defend against a contributor deliberately rewriting its own enforcement. There is no broad exception or disabled detector here.

The app candidate's checksum false positives are independently triaged in its separate handoff and must receive only exact, evidenced fingerprints. This CI repair does not accept those exceptions, the broader app candidate, its failing sign-out tests, its screenshot gate, or any release.
