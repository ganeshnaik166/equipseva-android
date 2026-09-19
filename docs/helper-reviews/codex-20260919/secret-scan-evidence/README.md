# Historical checksum finding proofs

These artifacts explain only the exact 208 findings from the original review range `e4a5e0db..4eff9984`. All were independently reproduced as source-file SHA-256 checksums. The final all-ancestry scan, including `--no-renames`, reports 70 distinct historical fingerprints, each present in that exhaustive ledger. The other 138 are duplicate presentations of identical report blobs under separate-parent merge diffs.

The two input JSON files contain only rule, commit, path and location metadata; matched values, matched lines, commit messages and author data were removed. Their hashes in the replayed ledger describe these sanitized inputs, not the original external reports. The 70-entry comparison file contains the final exact-flags findings despite its retained earlier filename. Original redacted reports remain in the workspace evidence directory.

`gitleaks-triage.py` reads historic Git objects plus the line-ending manifest. It requires the recorded commits/blobs and reproduces all checksums without reading current source files. To replay, copy this directory to a disposable evidence directory, then run:

```text
python <copied-directory>/gitleaks-triage.py --repo <full-checkout> --evidence-dir <copied-directory>
```

The replay must prove 208/208 findings, including 201 CRLF reconstructions and seven explicit mixed-ending reconstructions, and recommend exactly 70 fingerprints. Its `ignores_modified: false` field describes the review/reproducer: the script never changes the repository's ignore policy.

After the real-CLI coverage tests and independent critic/QA review, the coordinator installed only those 70 exact entries in `.gitleaksignore`. No detector, rule, directory, value pattern, baseline or whole commit was excluded. The original triage report's conditional/proposal wording records its earlier review phase. The root handoff records final scan results and the application blockers separately.

`gitleaks-positive-control-result.json` uses the unchanged project rules and exact 70 entries in a disposable synthetic repository. The direct CLI with final flags passed clean content (0) and detected a generated, never-issued GitHub-token-shaped value (23); the actual helper returned 0/1 respectively. Output redaction passed. No provider or real credential was used.

This evidence does not establish absence of secrets in all repository history or accept Android/release security.
