# Handoff — helper branch `claudedev-help`

**Read this first if you are the ChatGPT / Codex ("Astra") session resuming the
renewal program.** A second agent (Claude, at the owner's request) worked on this
repository after your session ran out of tokens. Everything it did is on the
branch `claudedev-help`, which was cut from your tip
`c927f7f4` (`codex/security-foundation-20260907`). Nothing was pushed to `main`,
`ops/**`, or `codex/**`, and no production migration or release was deployed.

## Ground rules the helper followed

- **Your plan governs.** `RENEWAL_EXECUTION_PLAN.md`, its milestones, quality
  gates, working rules and the design/flow decisions you recorded were not
  changed. The helper only executed the next queued item you left.
- **Your branch is untouched.** `codex/security-foundation-20260907` still
  points at `c927f7f4`. Diff the helper's work with
  `git diff c927f7f4...origin/claudedev-help`.
- **Additive only.** New files and new tests; existing behaviour was not
  redesigned. Where a defect in existing code was found, it is recorded below
  with evidence rather than silently reworked, unless the fix was required for
  the queued item and is called out explicitly.
- **One commit per milestone**, each pushed to `origin/claudedev-help`, each
  with the checks that were actually run in the message.

## Where you stopped (your own last status, 7 September 2026)

> Current focus is security and data reliability before the interface redesign.
> Implemented: evidence-access checks, account-safe draft recovery, and cron fixes.
> Verified: the latest Android and backend CI checks both passed.
> Next: integration tests for account switching, draft recovery and photo evidence
> before merging to main.
> UI: workflow planning and navigation review are done; redesigned screens are
> still pending.

## What the helper did on `claudedev-help`

Baseline re-verified on `c927f7f4` on the owner's Windows machine before any
change: `:app:testDebugUnitTest` BUILD SUCCESSFUL, 2,835 tests / 336 suites /
0 failures / 0 errors (matches your recorded count).

Milestone log (newest last; each entry is one commit):

| # | Commit | Scope | Checks run |
| --- | --- | --- | --- |
| 0 | this commit | Handoff note for the resuming session; memory of the working agreement | docs only |

Sections below are appended per milestone.

## Open items handed back to you

- Merge/no-merge of `codex/security-foundation-20260907` and of
  `claudedev-help` into `main` is the owner's call; the helper did not merge.
- r3821 / r3822 migrations remain undeployed candidates (per your commit
  messages). The helper did not deploy them.
- Local tooling note for this machine: Node.js and Python are **not installed**,
  so `supabase/tests` (PGlite) and `scripts/test_cron_response_summary.py` can
  only be exercised in GitHub Actions here. Gradle (JDK 17) works locally.
