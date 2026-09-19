"""Independent read-only triage. Never emits matched values or source content.

Writes only review artifacts in --evidence-dir. No Gitleaks ignores are edited.
The exhaustive ledger binds each reported commit/path/line to its exact Git blob,
its sourceFiles schema (or explicit review checksum heading), and recomputed
SHA-256 of the stated Kotlin source. CRLF reconstruction is recorded explicitly.
"""
from __future__ import annotations

import collections
import argparse
import hashlib
import json
import re
import subprocess
from functools import lru_cache
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--repo", type=Path, default=Path(r"C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-quality-integration-20260919"))
parser.add_argument("--evidence-dir", type=Path, default=Path(__file__).resolve().parent)
args = parser.parse_args()
ROOT = args.repo
OUT = args.evidence_dir
INPUT = OUT / "gitleaks-full-range-before.json"
LAYOUT_INPUT = OUT / "gitleaks-triage.mixed-line-endings.json"
START = "e4a5e0db903fae465e8ddb2c1348d657d98f032b"
END = "4eff9984941b63683263b6ed1ade11350ef4660a"
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-fA-F]{64}")
layout_manifest = json.loads(LAYOUT_INPUT.read_text(encoding="utf-8-sig"))
assert layout_manifest["format_version"] == 1
layouts = {(r["source_path"], r["source_git_blob_oid"]): r for r in layout_manifest["layouts"]}
assert len(layouts) == len(layout_manifest["layouts"]) == 2


def reconstruct_mixed_endings(content: bytes, layout: dict) -> bytes:
    """Transform only existing Git newline bytes; never read working source."""
    assert layout["default_newline"] == "CRLF"
    assert layout["preserve_final_newline_from_git_blob"] is True
    assert layout["source_git_blob_bytes"] == len(content)
    normalized = content.replace(b"\r\n", b"\n")
    endings = normalized.count(b"\n")
    positions = layout["bare_LF_line_numbers"]
    assert positions == sorted(set(positions))
    assert all(type(n) is int and 1 <= n <= endings for n in positions)
    assert len(positions) == layout["bare_LF_count"]
    assert endings == layout["newline_count"] == layout["CRLF_count"] + len(positions)
    bare = set(positions)
    pieces = normalized.split(b"\n")
    result = pieces[0] + b"".join(
        (b"\n" if line_no in bare else b"\r\n") + piece
        for line_no, piece in enumerate(pieces[1:], 1)
    )
    assert result.replace(b"\r\n", b"\n") == normalized
    assert result.count(b"\r\n") == layout["CRLF_count"]
    assert result.count(b"\n") - result.count(b"\r\n") == layout["bare_LF_count"]
    return result


@lru_cache(maxsize=None)
def git(*args: str) -> bytes | None:
    p = subprocess.run(["git", *args], cwd=ROOT, capture_output=True)
    return p.stdout if p.returncode == 0 else None


def get_blob(ref: str, path: str) -> tuple[str, bytes] | None:
    spec = f"{ref}:{path}"
    content = git("show", spec)
    oid = git("rev-parse", "--verify", spec)
    if content is None or oid is None:
        return None
    oid_text = oid.decode("ascii").strip()
    assert HEX40.fullmatch(oid_text), "Unexpected Git object identifier"
    return oid_text, content


def source_proof(ref: str, path: str, expected: str) -> dict:
    blob = get_blob(ref, path)
    if blob is None:
        return {"source_commit": ref, "source_found": False, "sha256_matches": False}
    oid, content = blob
    forms = [("raw_git_blob_bytes", content)]
    lf = content.replace(b"\r\n", b"\n")
    crlf = lf.replace(b"\n", b"\r\n")
    if lf != content:
        forms.append(("LF_normalization", lf))
    if crlf != content:
        forms.append(("CRLF_worktree_reconstruction", crlf))
    layout = layouts.get((path, oid))
    if layout is not None:
        forms.append(("recorded_newline_positions_reconstruction", reconstruct_mixed_endings(content, layout)))
    matches = [method for method, form in forms if hashlib.sha256(form).hexdigest() == expected.lower()]
    proof = {
        "source_commit": ref,
        "source_found": True,
        "source_git_blob_oid": oid,
        "source_git_blob_bytes": len(content),
        "sha256_matches": bool(matches),
        "matching_byte_forms": matches,
    }
    if "recorded_newline_positions_reconstruction" in matches:
        proof["mixed_ending_byte_proof"] = {
            "default_newline": "CRLF",
            "bare_LF_line_numbers": layout["bare_LF_line_numbers"],
            "newline_count": layout["newline_count"],
            "CRLF_count": layout["CRLF_count"],
            "bare_LF_count": layout["bare_LF_count"],
            "preserve_final_newline_from_git_blob": True,
            "source_git_blob_and_positions_reproduce_historic_sha256": True,
            "reconstruction_reads_worktree_source": False,
            "initial_worktree_provenance": layout["initial_worktree_provenance"],
        }
    return proof


data = json.loads(INPUT.read_text(encoding="utf-8-sig"))
assert len(data) == 208, "Input finding count changed; reassess scope"
assert len({r["Fingerprint"] for r in data}) == 208, "Unexpected duplicate fingerprint"
assert all("REDACTED" in r["Secret"] and "REDACTED" in r["Match"] for r in data), "Input is not fully redacted"
ledger = []

for number, finding in enumerate(data, 1):
    commit, path, line_no = finding["Commit"], finding["File"], finding["StartLine"]
    record = {
        "index": number,
        "fingerprint": finding["Fingerprint"],
        "rule": finding["RuleID"],
        "finding_commit": commit,
        "finding_file": path,
        "start_line": line_no,
        "end_line": finding["EndLine"],
        "start_column": finding["StartColumn"],
        "end_column": finding["EndColumn"],
        "matched_value": "[REDACTED]",
        "classification": "unresolved_do_not_ignore",
        "eligible_for_exact_fingerprint_disposition": False,
    }
    assert HEX40.fullmatch(commit), "Unexpected finding commit"
    document = get_blob(commit, path)
    if document is None:
        record["reason"] = "Historic document unavailable"
        ledger.append(record)
        continue
    doc_oid, raw = document
    body = raw.decode("utf-8-sig")
    lines = body.splitlines()
    assert 1 <= line_no <= len(lines), "Finding line outside historic file"
    assert finding["EndLine"] == line_no, "Unexpected multiline match; needs manual review"
    line = lines[line_no - 1]
    record["document_git_blob_oid"] = doc_oid
    record["document_git_blob_bytes"] = len(raw)
    record["historic_line_exists"] = True
    expected = None
    source = None
    refs = []

    if path.endswith("verification.json"):
        schema = json.loads(body)
        pair = re.fullmatch(r'\s*"([^"\\]+)"\s*:\s*"([^"\\]*)"\s*,?\s*', line)
        if pair:
            key, value = pair.groups()
            if (key.startswith("app/src/") and key.endswith(".kt")
                    and HEX64.fullmatch(value) and schema.get("sourceFiles", {}).get(key) == value):
                source, expected = key, value
                record["context"] = "sourceFiles object in build-verification receipt"
                record["schema_pointer"] = "/sourceFiles/" + key.replace("~", "~0").replace("/", "~1")
                record["schema_value_equals_historic_line_value"] = True
                record["value_shape"] = "64 hexadecimal characters"
                record["source_claim"] = "SHA-256 of raw build-input source bytes"
                for key_name in ("deliveryCommit", "foundationCandidateCommit", "baseCheckpoint", "baseCommit"):
                    candidate = schema.get(key_name)
                    if isinstance(candidate, str) and HEX40.fullmatch(candidate):
                        refs.append((key_name, candidate))
                record["document_declares_raw_worktree_line_endings"] = "line endings" in schema.get("sourceHashMethod", "")
    elif path == "docs/helper-reviews/codex-20260919/push-navigation-independent-review.md":
        pair = re.fullmatch(r"- DeviceTokenRegistrar\.kt: `([0-9a-fA-F]{64})`", line)
        if pair and "Reviewed file SHA-256:" in "\n".join(lines[max(0, line_no - 7):line_no]):
            source = "app/src/main/kotlin/com/equipseva/app/core/push/DeviceTokenRegistrar.kt"
            expected = pair.group(1)
            record["context"] = "DeviceTokenRegistrar entry under Reviewed file SHA-256 heading"
            record["schema_value_equals_historic_line_value"] = True
            record["value_shape"] = "64 hexadecimal characters"
            record["source_claim"] = "SHA-256 of reviewed source file"

    if expected is None or source is None:
        record["reason"] = "Did not prove a source-checksum schema; requires manual review"
        ledger.append(record)
        continue

    record["source_path"] = source
    refs.insert(0, ("finding_commit", commit))
    seen = set()
    proofs = []
    for origin, ref in refs:
        if ref in seen:
            continue
        seen.add(ref)
        proof = source_proof(ref, source, expected)
        proof["reference_origin"] = origin
        proofs.append(proof)
    record["source_verification"] = proofs
    matching = [p for p in proofs if p["sha256_matches"]]
    if matching:
        record["classification"] = "proven_nonsecret_source_sha256"
        record["eligible_for_exact_fingerprint_disposition"] = True
        record["reason"] = "Exact historic line is a source-checksum field; its value is reproduced from the named Kotlin source bytes. No credential value is required to explain the match."
    else:
        record["classification"] = "checksum_context_not_reproduced_do_not_ignore"
        record["reason"] = "Checksum-shaped value in source-checksum context, but no inspected source bytes reproduce it yet."
    ledger.append(record)

FINAL_INPUT = OUT / "gitleaks-all-parents-first-diff.json"
final_findings = json.loads(FINAL_INPUT.read_text(encoding="utf-8-sig"))
assert len(final_findings) == 70, "Comparison count changed; reassess scope"
assert all("REDACTED" in r["Secret"] and "REDACTED" in r["Match"] for r in final_findings), "Comparison report is not fully redacted"
final_fingerprints = {r["Fingerprint"] for r in final_findings}
assert len(final_fingerprints) == 70
assert final_fingerprints <= {r["fingerprint"] for r in ledger}, "Comparison contains previously untriaged fingerprints"
for record in ledger:
    record["observed_in_first_parent_diff_all_ancestry_scan"] = record["fingerprint"] in final_fingerprints
    record["recommended_exact_fingerprint_exception"] = record["eligible_for_exact_fingerprint_disposition"] and record["observed_in_first_parent_diff_all_ancestry_scan"]

def history_key(record):
    return record["document_git_blob_oid"], record["finding_file"], record["rule"], record["start_line"], record["end_line"]

final_content = {history_key(r) for r in ledger if r["observed_in_first_parent_diff_all_ancestry_scan"]}
omitted = [r for r in ledger if not r["observed_in_first_parent_diff_all_ancestry_scan"]]
assert all(history_key(r) in final_content for r in omitted), "Comparison omits distinct content; review required"

persistent_docs = []
for path in sorted({r["finding_file"] for r in ledger}):
    at_head = get_blob(END, path)
    assert at_head is not None
    historic_oids = {r["document_git_blob_oid"] for r in ledger if r["finding_file"] == path}
    persistent_docs.append({"file": path, "frozen_head_blob_oid": at_head[0], "matches_all_finding_document_blobs": historic_oids == {at_head[0]}})

summary = {
    "scanner_report": INPUT.name,
    "scanner_report_sha256": hashlib.sha256(INPUT.read_bytes()).hexdigest(),
    "range_exclusive_base": START,
    "range_inclusive_head": END,
    "scan_options": "--full-history --diff-merges=separate",
    "findings": len(ledger),
    "classifications": dict(collections.Counter(r["classification"] for r in ledger)),
    "rules": dict(collections.Counter(r["rule"] for r in ledger)),
    "files": dict(collections.Counter(r["finding_file"] for r in ledger)),
    "distinct_document_blobs": len({r.get("document_git_blob_oid") for r in ledger}),
    "distinct_source_paths": len({r.get("source_path") for r in ledger}),
    "findings_proven_by_source_at_finding_commit": sum(any(p["reference_origin"] == "finding_commit" and p["sha256_matches"] for p in r.get("source_verification", [])) for r in ledger),
    "findings_proven_by_documented_delivery_commit": sum(any(p["reference_origin"] == "deliveryCommit" and p["sha256_matches"] for p in r.get("source_verification", [])) for r in ledger),
    "findings_with_raw_git_blob_match": sum(any("raw_git_blob_bytes" in p.get("matching_byte_forms", []) for p in r.get("source_verification", [])) for r in ledger),
    "findings_with_crlf_reconstruction_match": sum(any("CRLF_worktree_reconstruction" in p.get("matching_byte_forms", []) for p in r.get("source_verification", [])) for r in ledger),
    "findings_with_recorded_newline_positions_match": sum(any("recorded_newline_positions_reconstruction" in p.get("matching_byte_forms", []) for p in r.get("source_verification", [])) for r in ledger),
    "worktree_source_reads_in_this_reproduction": 0,
    "line_ending_manifest": LAYOUT_INPUT.name,
    "line_ending_manifest_sha256": hashlib.sha256(LAYOUT_INPUT.read_bytes()).hexdigest(),
    "initial_raw_worktree_equality_provenance_retained": True,
    "source_values_and_raw_matching_lines_omitted": True,
    "ignores_modified": False,
    "comparison_scan": {
        "report": FINAL_INPUT.name,
        "report_sha256": hashlib.sha256(FINAL_INPUT.read_bytes()).hexdigest(),
        "options": "--full-history --diff-merges=first-parent --no-ext-diff --no-textconv --no-renames",
        "findings": len(final_findings),
        "rules": dict(collections.Counter(r["RuleID"] for r in final_findings)),
        "all_fingerprints_are_subset_of_triaged_208": True,
        "omitted_history_fingerprints": len(omitted),
        "every_omitted_fingerprint_has_identical_document_blob_line_and_rule_in_final_70": True,
        "recommended_individual_fingerprint_dispositions": sum(r["recommended_exact_fingerprint_exception"] for r in ledger),
        "recommendation_conditional_on_author_and_critic_merge_coverage_tests": True,
    },
    "persistent_docs_at_frozen_head": persistent_docs,
}
assert summary["classifications"] == {"proven_nonsecret_source_sha256": 208}, "Not all historical checksums reproduced; do not apply the proposed exceptions"
assert summary["findings_with_crlf_reconstruction_match"] == 201
assert summary["findings_with_recorded_newline_positions_match"] == 7
(OUT / "gitleaks-triage.json").write_text(json.dumps({"summary": summary, "findings": ledger}, indent=2) + "\n", encoding="utf-8")
recommended = sorted(r["fingerprint"] for r in ledger if r["recommended_exact_fingerprint_exception"])
(OUT / "gitleaks-triage.recommended-fingerprints.txt").write_text(
    "# PROPOSAL ONLY; no repository ignores were edited.\n"
    "# Exact 70 fingerprints from gitleaks-all-parents-first-diff.json.\n"
    "# All 208 original findings and byte proofs: gitleaks-triage.json.\n"
    "# Apply only after the scan author's and critic's real-CLI merge-coverage tests pass.\n"
    + "\n".join(recommended) + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2))
for record in ledger:
    if not record["eligible_for_exact_fingerprint_disposition"]:
        print(json.dumps({key: record.get(key) for key in ("fingerprint", "classification", "source_path", "reason")}, ensure_ascii=True))
