# Sharp advisory patch — independent QA, 26 September 2026

Scope: corrected frozen code commit `13bef61efd9d986d7f8b1b6a238b37d0d6376daf` on `codex/security-sharp-20260926`, based on `origin/main` `6a6b224681d3595b3c358a029e056e74496bac67`. The pushed [PR1885](https://github.com/ganeshnaik166/equipseva-android/pull/1885) head is docs-only successor `c37568a9aaa33c5baff29b787aedf885f2fd5b1f`. This review covers only the web lockfile update for GHSA-rgj7-g3m4-5g8c, not the Android app or a production deployment.

The [publisher's GitHub advisory](https://github.com/advisories/GHSA-rgj7-g3m4-5g8c) marks `sharp <0.35.4` affected and `0.35.4` patched, with prebuilt libheif `1.23.2`. The [upstream v0.35.4 release](https://github.com/lovell/sharp/releases/tag/v0.35.4) points to sharp-libvips `v1.3.3`.

Independent read-only checks on the corrected frozen code:

- `git show --stat 15726a63`: only `web/package-lock.json`, 119 insertions and 119 deletions. Corrective `git show 13bef61e` adds exactly 16 `libc` selectors (48 lines) in the same lockfile.
- Parsed `origin/main:web/package-lock.json` versus the corrected lock: zero package-key changes; exactly 27 modified package entries, all `sharp` or `@img/sharp-*`. The `sharp` and platform binaries move `0.35.3 → 0.35.4`; bundled libvips packages move `1.3.2 → 1.3.3`; root lock metadata unchanged. No application source, manifest or unrelated dependency changed.
- Independently fetched npm registry metadata for all 16 Linux `sharp` and `sharp-libvips` packages at the exact locked versions, then compared it with each lock entry: **16/16 match**, 0 missing or mismatched selectors. Six glibc architecture variants plus two musl variants exist in each of the two package families.
- Read installed `web/node_modules/sharp/package.json` and `@img/sharp-win32-x64/package.json`: both `0.35.4`. `node -e 'const s=require("sharp"); console.log(s.versions)'` returned sharp `0.35.4`, libvips `8.18.6`, libheif `1.23.2` on Windows.
- An in-memory 4×4 synthetic AVIF encode/decode through the installed Sharp binary returned format `heif`, 4×4, 284 bytes (exit 0).
- The `web/.next/BUILD_ID` artifact exists after the implementer's local build.

Implementer-reported **fresh checks after corrective SHA `13bef61e`**, using bundled Node `24.19.0` and `pnpm dlx npm@10.8.2` because bare `npm` is absent from PATH: `npm ci` exit 0 (101 packages), `npm run typecheck` exit 0, `npm test` exit 0 (`DataTable SMOKE PASSED`), `npm run build` with CI's placeholder `NEXT_PUBLIC_*` environment exit 0. QA inspected the build log's compilation and static-generation completion; these commands were not independently rerun by QA. The repository has no web lint script.

The prior frozen code at `15726a63` lacked all 16 Linux `libc` selectors; the critic's hold was valid, and its prior preliminary local 9.6 score was **not** acceptance. The correction now matches the npm registry. Fresh [GitHub web CI on Node 20/Linux](https://github.com/ganeshnaik166/equipseva-android/actions/runs/36236614153/job/108389433302) at pushed PR head `c37568a9` finished **success**: dependency install, typecheck, DataTable render smoke, and placeholder-environment build all completed successfully. Both [PR Gitleaks](https://github.com/ganeshnaik166/equipseva-android/actions/runs/36236614112/job/108389433157) and [push Gitleaks](https://github.com/ganeshnaik166/equipseva-android/actions/runs/36236612110/job/108389428174) finished **success**.

**Final scoped QA score: 9.7/10** for the corrected Sharp lockfile security update and PR checks. No mandatory defect remains in this bounded scope. Default-branch Dependabot alert closure can only be confirmed after a reviewed merge; this QA does not assert that the patch is on main, deployed, or validated against every production image path or musl runtime.
