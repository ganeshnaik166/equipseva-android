# Independent Gitleaks finding triage — 2026-09-19

**All 208 supplied findings are proven source-file SHA-256 checksums. No unresolved or suspected credential remains among these 208.** This is a disposition of these exact findings, not a claim that the repository or all its history contains no secrets.

The reviewer read historic Git objects and local source bytes only. No repository source, workflows, ignores, commits, or Gradle execution changed. Matched values and complete matched lines are omitted from this report and ledger.

## Scope and exhaustive records

- Scanner: Gitleaks 8.24.3; coordinator-provided redacted JSON.
- Exact reviewed range: `e4a5e0db903fae465e8ddb2c1348d657d98f032b..4eff9984941b63683263b6ed1ade11350ef4660a`.
- Original options: `--full-history --diff-merges=separate`; 208 distinct fingerprints, 190 generic-rule and 18 Sentry-rule matches.
- `gitleaks-triage.json` records **every** fingerprint, rule, commit, historic path/line/columns, document Git blob, checksum schema, corresponding source path/ref/blob, byte-reproduction method, and exact-fingerprint recommendation. No matched value is retained.
- `gitleaks-triage.py` reproduces the read-only analysis and writes only external reports. It validates the supplied finding counts, full input redaction, historical lines/schema, source-byte hashes, and comparison-set coverage; failures stop the script. Reproduction reads Git objects and the saved evidence artifacts, **never working source files**.
- `gitleaks-triage.mixed-line-endings.json` pins two exact source Git blobs and the one-based line numbers whose endings are LF rather than the default CRLF. It preserves initial working-byte/equality provenance and contains no source dump or matched values.

| Historical document | Original findings | Comparison findings | Context |
| --- | ---: | ---: | --- |
| `docs/evidence/auth-integration/verification.json` | 69 | 23 | Kotlin source entries in `sourceFiles` |
| `docs/evidence/ui-foundation/verification.json` | 69 | 23 | Kotlin source entries in `sourceFiles` |
| `docs/evidence/ui-inputs/verification.json` | 69 | 23 | Kotlin source entries in `sourceFiles` |
| `docs/helper-reviews/codex-20260919/push-navigation-independent-review.md` | 1 | 1 | Explicit reviewed-file SHA-256 section, line 51 |
| **Total** | **208** | **70** | **All proven nonsecrets** |

The 207 JSON entries all resolve to their exact `sourceFiles` member at the reported historical line. The rules matched security-related source names, including Auth, Password, DeviceToken, EsTokens, and Sentry, adjacent to legitimate source checksums. The Sentry matches are source-file checksums too; they are not Sentry credentials.

## Byte-level proof, including mixed endings

Context or hexadecimal shape alone was not accepted. Each flagged value was compared in memory with SHA-256 calculated from the named source bytes.

- **201 findings:** reproduced from historical Git source blobs by converting LF to Windows CRLF. These receipts describe hashes of raw laptop build inputs, so Git's normalized blob bytes are not the claimed byte representation. Each matching source ref/blob and conversion is in the ledger.
- **Six EsTokens findings:** the exact existing bytes in `work/equipseva-auth-integration-20260911/app/src/main/kotlin/com/equipseva/app/designsystem/theme/EsTokens.kt` reproduce the recorded checksum. This file has **20 CRLF and 6 bare-LF line endings**. Replacing CRLF with LF, and making no other content change, exactly equals the historical source blob in both the finding commit and the receipts' delivery commits. This proves the mixed-ending build-input checksum without guessing a hash.
- **One review-document finding:** the exact existing bytes in `work/equipseva-quality-integration-20260919/app/src/main/kotlin/com/equipseva/app/core/push/DeviceTokenRegistrar.kt` reproduce its recorded reviewed-file checksum. This file has **124 CRLF and 8 bare-LF line endings**. CRLF-to-LF normalization alone exactly equals the source blob at `5aaa78f073e00d82e6e211bd3ac2d548e14a3f39`.

The initial observations above are retained as provenance; future verification does not depend on those worktree bytes surviving a checkout. The seven mixed-ending findings are now independently reconstructed from these exact Git blobs:

| Source | Pinned Git blob | One-based source lines ending in LF; all other existing newlines use CRLF |
| --- | --- | --- |
| `EsTokens.kt` | `130b7add131f1a9a30e0a1bbafa1e5b5d033b420` | 5, 8, 9, 10, 11, 22 |
| `DeviceTokenRegistrar.kt` | `fe1d508ada11079947a01d42cfa1f23b78eea55d` | 43, 44, 106, 107, 108, 109, 110, 128 |

Algorithm: normalize Git CRLF to LF, preserve every other content byte and final-newline presence, then use CRLF at each existing newline except the listed LF-ending source lines. The reconstructed byte arrays equal the initially observed raw files and reproduce the historic checksums. The replay verifies the Git blob identity/byte count, unique/in-range positions, newline counts, normalized byte equality, and final SHA-256 comparison. Every relevant ledger proof now contains these positions and its original equality provenance.

Run `python gitleaks-triage.py --repo <checkout-or-Git-directory-with-the-recorded-objects> --evidence-dir <artifact-directory>`. Keep both original redacted scan reports and the line-ending manifest beside the reproducer. No network or working-source reads are needed. The current replay ran with `--repo` pointing directly at the shared `.git` object store and exited 0: all 208 findings, including all seven position-reconstructed proofs, with **zero worktree source reads**. Missing Git objects or a changed/mismatching layout fails verification; it does not silently approve fewer findings.

Receipt delivery refs independently checked are auth `7f3c5eaa8c8ae218433f3217b86ea34e9a08691b`, foundation `c7da5ee333d3913bf98052c9c20f81b3b56f6d38`, and inputs `694bf690929f869277513d27f72bf24697a3d2a5`. All 207 receipt matches reproduce against their corresponding delivery ref. All four historical document blobs also match their files in frozen candidate HEAD `4eff9984`; a currently uncommitted one-line formatting change is outside this historical-object comparison.

## Minimal, auditable handling

The coordinator's comparison report, `gitleaks-all-parents-first-diff.json`, uses `--full-history --diff-merges=first-parent` **without restricting traversal to first-parent ancestry**. It contains exactly 70 fingerprints: 64 generic-rule and six Sentry-rule matches. All are members of the fully triaged 208. Each of the omitted 138 fingerprints refers to an identical document blob, file, line, and rule present among the 70; they are duplicate historic merge presentations of the same checksum content. This comparison alone does not prove general merge-coverage correctness.

Recommended handling, conditional on the scan author's and independent critic's real-CLI merge-coverage fixtures passing:

1. Use only the **70 exact fingerprints** in `gitleaks-triage.recommended-fingerprints.txt`, with a reference to this ledger and its byte proofs. This text is a proposal, not an installed ignore file.
2. Do not use a baseline, directory exemption, generic hash regex, rule disablement, commit-wide exception, or source-name allow-list. An unrelated finding at the same path in a new commit must still be reviewed.
3. Re-run the final complete changed-range scan after those precise entries. Independently confirm that a synthetic real-secret positive control remains detectable with that same configuration, including side-branch and merge-introduced cases owned by the CI-fix reviewer.
4. Keep the 208-finding ledger as the audit record, but do not add the 138 duplicate-presentation fingerprints to the proposed 70-entry set. If the chosen scan mode changes, review new fingerprints explicitly.

No credential revocation is indicated by these checksum findings. This triage does not close any app-security, S1/S3 ownership, CI-history coverage, device, or release gate.
