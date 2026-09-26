# Independent critic: Sharp advisory patch, 2026-09-26

## Frozen review target

- PR [#1885](https://github.com/ganeshnaik166/equipseva-android/pull/1885), branch `codex/security-sharp-20260926`, head `9205dd37da57c938cac63889247e263916bfed74`.
- Code commit `15726a634fe9c6d36516f07c4b92df9314b4718d`, based on `origin/main` `6a6b224681d3595b3c358a029e056e74496bac67`. Checkout was clean; no repo file was edited by the critic.
- Scope: web console's transitive Sharp lockfile update for [GHSA-rgj7-g3m4-5g8c](https://github.com/advisories/GHSA-rgj7-g3m4-5g8c). This is not an Android, deployment, all-alerts, or image-upload security review.

## Result and mandatory finding

**Scoped score on frozen code: 9.2/10, hold.** Version, integrity, and dependency scope are sound, but the 16 new Linux package records omit their published `libc` selectors. This fails the >=9.5 acceptance bar. Correct the metadata, rerun lock install and Linux CI on a new frozen SHA, then obtain fresh independent review.

The lock entries below have `os: ["linux"]` and CPU constraints but no `libc`. Each package's live npm registry metadata requires either `glibc` or `musl`; the old [Dependabot patch](https://github.com/ganeshnaik166/equipseva-android/pull/1867) also carries the selector for all 16. The candidate's integrity strings match the registry for all 16, so this is missing platform metadata, not a tampered tarball. On Linux, npm may try an inapplicable optional binary or change package selection/installation behavior. Local Windows success cannot prove Linux behavior.

Expected `libc: ["glibc"]`:

- `node_modules/@img/sharp-libvips-linux-arm` (`web/package-lock.json:581`)
- `node_modules/@img/sharp-libvips-linux-arm64` (`:597`)
- `node_modules/@img/sharp-libvips-linux-ppc64` (`:613`)
- `node_modules/@img/sharp-libvips-linux-riscv64` (`:629`)
- `node_modules/@img/sharp-libvips-linux-s390x` (`:645`)
- `node_modules/@img/sharp-libvips-linux-x64` (`:661`)
- `node_modules/@img/sharp-linux-arm` (`:709`)
- `node_modules/@img/sharp-linux-arm64` (`:731`)
- `node_modules/@img/sharp-linux-ppc64` (`:753`)
- `node_modules/@img/sharp-linux-riscv64` (`:775`)
- `node_modules/@img/sharp-linux-s390x` (`:797`)
- `node_modules/@img/sharp-linux-x64` (`:819`)

Expected `libc: ["musl"]`:

- `node_modules/@img/sharp-libvips-linuxmusl-arm64` (`web/package-lock.json:677`)
- `node_modules/@img/sharp-libvips-linuxmusl-x64` (`:693`)
- `node_modules/@img/sharp-linuxmusl-arm64` (`:841`)
- `node_modules/@img/sharp-linuxmusl-x64` (`:863`)

Evidence: I requested each of the 16 `name/version` metadata records directly from `registry.npmjs.org` and compared `dist.integrity` and `libc` with this lock. All 16 integrities matched and all 16 lock `libc` values were absent despite registry selectors. Representative primary records: [sharp Linux x64](https://registry.npmjs.org/@img%2fsharp-linux-x64/0.35.4), [sharp Linux musl x64](https://registry.npmjs.org/@img%2fsharp-linuxmusl-x64/0.35.4), [libvips Linux x64](https://registry.npmjs.org/@img%2fsharp-libvips-linux-x64/1.3.3), [libvips Linux musl x64](https://registry.npmjs.org/@img%2fsharp-libvips-linuxmusl-x64/1.3.3). A field-by-field comparison of all Sharp entries against Dependabot commit `1e760c8` found **only these 16 absent `libc` fields**. The six unrelated nested Tailwind entries in the bot lock were correctly excluded.

## What passed and remains open

- `git show --stat 15726a63` modifies only `web/package-lock.json` (119 additions, 119 deletions); semantic JSON comparison with parent shows 27 modified entries, all Sharp or Sharp-libvips, and no package-key additions/removals. Root manifest, Next 16.3.3, and other lock entries are unchanged. `git diff --check` passed.
- Sharp and platform binaries resolve `0.35.4`; Sharp-libvips binaries resolve `1.3.3`. The publisher's advisory marks `<0.35.4` affected, and local installed Sharp reports libheif `1.23.2` in the implementer/QA evidence. I did not rerun local `npm ci`, typecheck, DataTable smoke or build; the handoff reports all four passed on Node 24/npm 10.8.2, and independent QA confirmed installed Windows Sharp and a synthetic AVIF roundtrip.
- At the last check of GitHub's check-run API for `9205dd37`, push and PR Gitleaks were complete/success; `build + typecheck` on Node 20/Linux was still in progress. PR is draft and undeployed. Do not report CI green or Dependabot alert #17 closed until observed after the correction and merge.
- No direct `sharp`/`next/image` import or upload/processing route was found in `web/src` during the preparatory source trace. This limits demonstrated current input exposure, but does not establish production image-optimizer reachability. It does not reduce the need for the patched lock.

## Acceptance after correction

Add the exact 16 selectors from published metadata (preserve existing versions and integrity), confirm semantic diff remains limited to Sharp entries, rerun `npm ci`, and require the fresh PR `web` and secret-scan checks to pass on the new SHA. The alert and hosted runtime require separate confirmation after merge/deployment. Re-score the corrected frozen patch; the present 9.2 is not an approval.

## Corrected frozen re-review, superseding the 9.2 hold

- New code SHA: `13bef61efd9d986d7f8b1b6a238b37d0d6376daf`; pushed clean PR head: `c37568a9aaa33c5baff29b787aedf885f2fd5b1f`. Local and `origin/codex/security-sharp-20260926` matched at review. This section does not retroactively approve code SHA `15726a63`.
- `git diff 9205dd37..13bef61e` changes only `web/package-lock.json`, adding 48 lines for exactly 16 `libc` arrays. Parsed lockfile comparison found precisely 16 changed fields, all `libc`, with values equal to npm registry metadata and Dependabot commit `1e760c8`. No versions, integrity hashes, manifest data, unrelated packages, or source changed. `git diff --check` passed.
- The corrected handoff records fresh `npm ci` (101 packages), typecheck, DataTable smoke and Next build all exit 0 on local Node 24/npm 10.8.2. These are implementer-run checks; I did not duplicate them.
- I read the public GitHub check-run API for head `c37568a9` after completion: fresh PR `build + typecheck` on Node 20/Linux **success**, and both push/PR `gitleaks` **success**. The Linux web check completed 2026-09-26 10:47:02 UTC. [PR1885](https://github.com/ganeshnaik166/equipseva-android/pull/1885) remained draft at the prior page read, and no deployment or default-branch alert closure was verified.

**Corrected scoped critic score: 9.6/10, locally accepted for the Sharp lockfile security update. No remaining mandatory code defect in this bounded patch.** The old 9.2 hold remains as evidence of the repaired issue. Independent QA should score this exact corrected SHA. Main merge, Dependabot alert #17 closure and hosted runtime version remain separate integration checks; this score is not an app-wide security rating.
