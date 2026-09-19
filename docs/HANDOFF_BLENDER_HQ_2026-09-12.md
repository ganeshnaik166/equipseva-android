# Blender headquarters milestone — 12 September 2026

## Current outcome

The user's exact logo anchors a real Blender campus, with seven robot offices,
clickable headquarters details, continuous illustrative work loops and a closed
Security → QA/critic → GitHub Main release lane. Android remains on hold.
Local implementation and bounded reviews pass. The site is NOT publicly deployed.

Branch: `codex/auth-integration-20260911`.
Starting HEAD: `cc896587fc4b456a624ef2dc0036fafe0de4a65b`.
Reviewed implementation commit: `176b5e1ba404468658a11da7fb644d2fa6e24cac`.
Implementation tree: `6f02423fd2642cea747ff021e72f88cf4c7b6d4f`.
This handoff, named outcome, fixture stabilization and HQ-02 record form a later
metadata/test commit. Read its exact SHA with `git log -1 --format=%H -- docs/HANDOFF_BLENDER_HQ_2026-09-12.md`.
No main merge/push, Android build or DNS edit occurred.

## Files and source

- `design/blender/equipseva-headquarters.blend`: editable Blender source, packed logo.
- `design/blender/README.md`: provenance, hashes, rebuild instructions and limits.
- `scripts/build_hq_scene.py`: all mesh creation, animations, GLB export and rendering.
- `website/progress-assets/`: GLB, original SVG, WebP fallback, scene manifest and pinned local Three.js.
- `website/progress-dashboard.html`, `.js`, `-data.json`: campus entry, frozen records and evidence.
- `website/progress-hq.js`, `.css`: interactive 3D view, accessible office directory, controls.
- `scripts/refresh_progress_snapshot.mjs`: explicit new-major publication only; same-directory atomic write.
- `scripts/package_progress_dashboard.mjs`: 19-file public allowlist, no private/editor source.
- `scripts/tests/progress-dashboard*.test.cjs`: controller, publisher, package and scene checks.

All models were created with portable Blender 4.5.9 LTS, not image-generated
stand-ins. The logo SVG matches the provided Downloads file byte for byte.
GLB is about 5.2 MB; WebP fallback about 41 KB. Runtime imports are local.
Blender download SHA-256 and Three.js npm SHA-512 were independently compared
with official distribution metadata. Sources and MIT license are retained.
The only diff-whitespace warning is an upstream indent in vendored three.core.js;
authored files pass diff checking. No failure suppression was added.

## Verification and independent scores

```text
node --test scripts/tests/progress-dashboard.test.cjs scripts/tests/progress-dashboard-delivery.test.cjs
26 passed, 0 failed/skipped/cancelled
node --check website/progress-hq.js
```

Independent QA reran the 26 checks. Root also verified the updated HQ-02 fixture.
The first package-test run had an incorrect expected file count (21 vs the
19 explicitly listed assets); its assertion was corrected to the actual contract.
Publishing HQ-02 exposed a test's hardcoded next ID/sequence; it now derives a
strictly newer synthetic ID/sequence from the fixture, preserving its assertion.
No failing tests were deleted, skipped, or renamed into passing results.

Independent critic: **9.55/10**. Dimensions: correctness 9.6, security/privacy
presentation 9.5, recovery/integrity 9.5, accessibility 9.6, visual 9.6,
performance/operations 9.5.
Independent QA: **9.6/10**. Correctness 38.5/40, security/data minimization 29/30,
accessibility 19/20, maintainability 9.5/10.
These accept the local campus slice only, not Android, public hosting, full
security audit, real mobile device/TalkBack or long-duration performance.

Chrome evidence: desktop and 390x844 responsive campus; no horizontal overflow;
44px office targets; office selection opens visible focused details; Escape
restores visible initiating control; dark-green focus ring on light surfaces;
pause/resume; OS reduced motion; Simple view; deliberately blocked GLB falls
back to poster and usable office controls. Browser overrides restored.
No dashboard console errors observed. Source, poster and actual GLB inspected.

Review fixes: offscreen desktop drawer, low-contrast focus ring, dashboard reviews
unlocking Android lane, incomplete selected-office updates, missing agent capture
timestamp and missing independent-review/provenance checks.

## Honest milestone/data behavior

HQ-02 is the reviewed local-campus record. Existing record IDs are immutable in
the browser; lower/equal sequences do not replace data. A complete newer major
record is validated and deeply frozen before an atomic UI event. Animations do
not increment progress, hours, commits, usage, agent activity or approvals.

To publish a genuinely new milestone, first author verified observations, then:

```text
node scripts/refresh_progress_snapshot.mjs --major-milestone HQ-03 --title "Actual completed milestone"
```

No routine invocation is allowed. No automated publisher/heartbeat was created.
The page checks once per minute for a new published major JSON; it cannot publish
local work or connect to Codex. Actual agent timestamps and quota timestamps are
independent and preserved by Git refresh. Source HEAD denotes captured Git facts,
not a claim that dirty Android files were committed or tested.

Usage captured via Codex tool at 09:44:30 UTC: Codex 7-day 11% used; Spark 5-hour
62% used; Spark 7-day 28% used. No account ID is exported. Expired quota windows
show unavailable until recaptured. Overall app completion remains not measured;
active hours remain not tracked. No guessed percentage or elapsed-hours estimate.

Release lane is informational, not GitHub protection. It requires Android scope,
matching candidate tree, evidence references/times/reviewers, mandatory checks,
zero blockers, separate QA/critic labels and all applicable critical scores >=9.5.
Producer attests evidence validity; the static page cannot authenticate reviews.
Main integration needs a separate observed remote-main SHA and evidence reference.
Current Android candidate/reviews are absent, so the lane remains locked.

## Upload blocker and bounded deployment route

Previous Chrome `fileChooser.setFiles` returned JSON-RPC -32000 "Not allowed".
Official browser troubleshooting requires the user to enable **Allow access to
file URLs** in ChatGPT Chrome extension Details. Do not bypass that permission.
No new upload attempt was made after this design change; no Worker was created.

New staging path: `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/progress-hq-release-20260912`.
Package with `node scripts/package_progress_dashboard.mjs <new-empty-directory>`.
It includes 19 files, nested assets/vendor preserved; source Blend/PNGs are excluded.
Old progress-dashboard-release/deploy-20260912 packages are superseded.

Hosting facts were verified earlier in this session: GoDaddy registrar;
Cloudflare DNS; GitHub Pages main:/docs serves existing legal/contact site;
an unrelated old equipseva-android Worker exists. Preserve apex, DNS and email.
Use NEW static Worker `equipseva-progress` with ONLY these routes:

- `equipseva.com/progress-dashboard*`
- `equipseva.com/progress-hq*`
- `equipseva.com/progress-assets/*`

Use an upload mode preserving the directory tree (folder/archive as supported).
Do not flatten nested files with a multi-file chooser. If UI cannot preserve
folders, stop and record that limitation; no broad existing Worker replacement.
No paid upgrade authorized. After deployment verify all assets, CSP, HTTPS,
no-store, noindex, nosniff, fallback/404 and homepage/privacy/assetlinks unchanged.
Public route/headers remain unverified until then.

## Checkout preservation

Three pre-existing Android modifications remain untouched and uncommitted:
DeepLinkPolicy.kt, DeepLinkRouter.kt and DeepLinkRouterTest.kt.
Do not reset, clean or stage them during dashboard delivery. Fetch before future
commits/pushes; another session can use this checkout. Push only this branch.
