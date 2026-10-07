# Immersive homepage — saved and stopped

Owner requested stop/save on 7 October 2026. **Do not continue, merge or deploy until the owner resumes.**

- Branch: `codex/homepage-3d-20261007`, isolated `work/equipseva-homepage-20261007`.
- Saved implementation: `4ac9253a07c4e28a73aa48f05f938ad0f24a5da2`.
- Public base: `49c163ebfe9bacc6b693b95a5218c9c1ac749dd8`.
- [PR1911](https://github.com/ganeshnaik166/equipseva-android/pull/1911) remains WIP/unmerged. The existing public homepage is unchanged.

## Direction and completed work

The owner changed the earlier landing-page direction to an immersive reference at
`why.zero.university`, then acknowledged the boundary around copying third-party
assets/music. Codex stated the original-assets route before resuming. The new
version uses original procedural 3D assets and an original generative ambient
score; no reference models, textures, recordings or source were copied.

Saved: five full-screen chapters for the idea, hospitals, engineers, teams and
contact; original articulated robotic hand, equipment monitor and healthcare
campus; scroll-driven scene/camera changes; floating chapter navigation; motion
and optional audio controls; reduced-motion and SVG fallbacks. Fonts/logo and
honest in-development framing remain. Authored HTML/CSS/JS were formatted.

No app/backend, legal/recovery, global Pages configuration, other checkout or
Gradle reservation changed. No production deployment or DNS change occurred.

## Exact evidence and open work

- `pnpm run build` and `pnpm run check` passed; scene bundle **720,413 bytes**.
- `pnpm audit --json`: **0 advisories**. These do not establish acceptance.
- Independent initial browser matrix: **65/86 passed, 21 failed**, on evolving
  WIP source. The final CSS wrapping fix was not retested before owner stop.
- Failures: **10** custom-spacing overflow checks, **4** menu-navigation heading
  focus checks, **4** missing dock-landmark checks, **2** unresolved audio
  mute/state compound assertions, **1** source-stability check during edits.
- Menu navigation reproduced focus returning to BODY. The pending-audio-resume
  race hypothesis was **not reproduced** by its finite focused probe; this
  does not resolve the two separate audio assertion failures.
- Axe retained **41/44 contrast-incomplete nodes**, depending on viewport.
  Manual rendered contrast remains necessary. No fresh QA acceptance score.
- Critic initial provisional score approximately **8.2/10**, with mobile copy
  separation, campus contrast, dock overlap and custom-spacing findings.
  Fixes were applied (line breaks, stronger campus scrim, final-section bottom
  clearance and `overflow-wrap:anywhere`), but final review remains incomplete.
- Earlier homepage **9.5/9.6** ratings apply only to the superseded source
  `41cdeec4`. Never use them to accept this immersive rebuild.

Local evidence is preserved under `outputs/homepage-immersive-qa-20261007`
(including `QA_WIP_STOP.md`, raw `initial/results.json`, focused probe and
screenshots) and `outputs/homepage-immersive-critic-20261007` plus its report.
Both QA browser runs completed and closed before stop; no new verification
started after the stop instruction. Earlier scanner/harness failures remain
recorded in `HANDOFF_HOMEPAGE_2026-10-07.md`; no waiver was added.

## Resume only on owner instruction

1. Fetch and verify this branch/source plus other sessions' ownership.
2. Fix menu heading focus and dock navigation semantics. Diagnose each failed
   audio gain/state assertion separately; preserve original failures.
3. Verify wrapping at 320/390 with expanded text spacing; inspect campus contrast
   and dock/content clearance. Test real tab visibility/GPU lifecycle separately.
4. Freeze source; rerun the bounded browser suite; get fresh independent critic
   and QA at least 9.5 without unresolved gates.
5. Require applicable hosted checks, then merge only the reviewed homepage;
   verify live assets/contact/legal/recovery/app links. No app acceptance implied.

Save commits use `[skip ci]` because the owner stopped work. Hosted acceptance
for this rebuild remains pending; an earlier green run is not its verification.
